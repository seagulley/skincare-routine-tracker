//
//  OnboardingView.swift
//  SkincareTracker
//
//  First-launch setup: Health access, notifications, and reminder preferences.
//

import SwiftUI

/// Optional override for Health access action. Used in tests to invoke the action directly without simulating a tap.
private struct HealthAccessRequestActionKey: EnvironmentKey {
    static let defaultValue: (() async -> Void)? = nil
}
extension EnvironmentValues {
    var healthAccessRequestAction: (() async -> Void)? {
        get { self[HealthAccessRequestActionKey.self] }
        set { self[HealthAccessRequestActionKey.self] = newValue }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var reminderService: ReminderService
    @EnvironmentObject var healthKitService: HealthKitServiceBase
    @Environment(\.healthAccessRequestAction) private var healthAccessRequestAction

    let onComplete: () -> Void

    @State private var wantsReminders = true
    @State private var isRequestingHealth = false
    @State private var isRequestingNotifications = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                header

                if type(of: healthKitService).isAvailable {
                    healthSection
                }

                notificationsSection
                remindersToggle

                continueButton
            }
            .padding(24)
        }
        .background(AppColors.background)
        .interactiveDismissDisabled()
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Welcome")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)
            Text("Let's set up your skincare reminders")
                .font(.body)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundStyle(AppColors.textOnAccent)
                    .frame(width: 44, height: 44)
                    .background(AppColors.accent)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Health app")
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("We use your sleep data to remind you at the right times—when you wake up and before bed.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Button {
                if let action = healthAccessRequestAction {
                    Task { await action() }
                } else {
                    Task { await requestHealthAccess() }
                }
            } label: {
                HStack {
                    if isRequestingHealth {
                        ProgressView()
                            .tint(AppColors.textOnAccent)
                    } else {
                        Text("Allow Health Access")
                            .fontWeight(.medium)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColors.accent)
                .foregroundStyle(AppColors.textOnAccent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityIdentifier("allowHealthAccess")
            .disabled(isRequestingHealth)
        }
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.title2)
                    .foregroundStyle(AppColors.textOnAccent)
                    .frame(width: 44, height: 44)
                    .background(AppColors.accent)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Notifications")
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("We'll send you gentle reminders for your skincare routine.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Button {
                Task { await requestNotificationPermission() }
            } label: {
                HStack {
                    if isRequestingNotifications {
                        ProgressView()
                            .tint(AppColors.textOnAccent)
                    } else {
                        Text("Enable Notifications")
                            .fontWeight(.medium)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColors.accent)
                .foregroundStyle(AppColors.textOnAccent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isRequestingNotifications)
        }
    }

    private var remindersToggle: some View {
        Toggle(isOn: $wantsReminders) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Morning & night reminders")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Text("Get reminded every morning and night for your skincare routine.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .tint(.green)
        .padding()
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var continueButton: some View {
        Button {
            completeOnboarding()
        } label: {
            Text("Continue")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppColors.accent)
                .foregroundStyle(AppColors.textOnAccent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.top, 8)
    }

    private func requestHealthAccess() async {
        isRequestingHealth = true
        defer { isRequestingHealth = false }
        try? await healthKitService.requestAuthorization()
    }

    private func requestNotificationPermission() async {
        isRequestingNotifications = true
        defer { isRequestingNotifications = false }
        _ = await reminderService.requestPermission()
    }

    private func completeOnboarding() {
        if wantsReminders {
            var morningConfig = store.reminderConfig(for: .morning)
            var nightConfig = store.reminderConfig(for: .night)
            morningConfig.isEnabled = true
            nightConfig.isEnabled = true
            store.updateReminderConfig(morningConfig)
            store.updateReminderConfig(nightConfig)
            Task {
                await rescheduleReminders()
            }
        }
        UserDefaults.standard.set(true, forKey: Self.onboardingCompleteKey)
        onComplete()
    }

    private func rescheduleReminders() async {
        var healthWakeTime: (hour: Int, minute: Int)? = nil
        var healthBedtime: (hour: Int, minute: Int)? = nil
        let morningConfig = store.reminderConfig(for: .morning)
        let nightConfig = store.reminderConfig(for: .night)
        if (morningConfig.useHealthWakeTime && morningConfig.isEnabled) || (nightConfig.useHealthBedtime && nightConfig.isEnabled) {
            try? await healthKitService.requestAuthorization()
            if morningConfig.useHealthWakeTime, morningConfig.isEnabled {
                healthWakeTime = await healthKitService.fetchTypicalWakeTime()
            }
            if nightConfig.useHealthBedtime, nightConfig.isEnabled {
                healthBedtime = await healthKitService.fetchTypicalBedtime()
            }
        }
        await reminderService.rescheduleReminders(
            configs: store.reminderConfigs,
            productsForDate: { store.productsForDate($0, routineType: $1) },
            healthWakeTime: healthWakeTime,
            healthBedtime: healthBedtime
        )
    }

    static let onboardingCompleteKey = "com.skincaretracker.onboardingComplete"

    static var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: onboardingCompleteKey)
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .environmentObject(AppStore())
        .environmentObject(ReminderService())
        .environmentObject(HealthKitService())
}
