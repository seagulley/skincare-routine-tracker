//
//  OnboardingView.swift
//  SkincareTracker
//
//  First-launch setup: Health access, notifications, and reminder preferences.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var reminderService: ReminderService
    @EnvironmentObject var healthKitService: HealthKitServiceBase

    let onComplete: () -> Void

    @State private var wantsNotifications = false
    @State private var syncRemindersWithHealthSleep = false
    @State private var isRequestingNotifications = false
    @State private var isRequestingHealth = false

    private var healthKitAvailable: Bool {
        healthKitService.isHealthKitDataAvailable
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                header

                notificationsSection

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

            Toggle(isOn: $wantsNotifications) {
                HStack(spacing: 8) {
                    if isRequestingNotifications {
                        ProgressView()
                            .scaleEffect(0.9)
                    }
                    Text("Enable morning & night reminders")
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
            .accessibilityIdentifier("enableRemindersToggle")
            .tint(.green)
            .padding()
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .disabled(isRequestingNotifications)
            .onChange(of: wantsNotifications) { _, isOn in
                if isOn {
                    Task { @MainActor in
                        await requestNotificationPermission()
                    }
                } else {
                    syncRemindersWithHealthSleep = false
                }
            }

            if wantsNotifications, healthKitAvailable {
                Toggle(isOn: $syncRemindersWithHealthSleep) {
                    HStack(spacing: 8) {
                        if isRequestingHealth {
                            ProgressView()
                                .scaleEffect(0.9)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sync with reminders with your Health app sleep schedule")
                                .fontWeight(.medium)
                                .foregroundStyle(AppColors.textPrimary)
                        }
                    }
                }
                .tint(.green)
                .padding()
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .accessibilityIdentifier("healthSleepSyncToggle")
                .disabled(isRequestingHealth)
                .onChange(of: syncRemindersWithHealthSleep) { _, isOn in
                    if isOn {
                        Task { @MainActor in
                            await requestHealthAccessWithWatchdog()
                        }
                    }
                }
            }
        }
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

    /// Runs Health authorization off the SwiftUI `onChange` turn (see `HealthKitService`) and clears the spinner
    /// after a timeout if the system never calls back (beta OS / presentation bugs).
    @MainActor
    private func requestHealthAccessWithWatchdog() async {
        isRequestingHealth = true

        let watchdog = Task { @MainActor in
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            isRequestingHealth = false
            syncRemindersWithHealthSleep = false
        }

        await Self.performHealthAuthorizationRequest(healthKitService: healthKitService)
        watchdog.cancel()
        isRequestingHealth = false
    }

    /// Same authorization path as the Health sleep sync toggle; used by `HealthKitAccessTests`.
    static func performHealthAuthorizationRequest(healthKitService: HealthKitServiceBase) async {
        try? await healthKitService.requestAuthorization()
    }

    @MainActor
    private func requestNotificationPermission() async {
        isRequestingNotifications = true
        defer { isRequestingNotifications = false }
        _ = await reminderService.requestPermission()
    }

    private func completeOnboarding() {
        if wantsNotifications {
            var morningConfig = store.reminderConfig(for: .morning)
            var nightConfig = store.reminderConfig(for: .night)
            morningConfig.isEnabled = true
            nightConfig.isEnabled = true
            let useHealth = syncRemindersWithHealthSleep && healthKitAvailable
            morningConfig.useHealthWakeTime = useHealth
            nightConfig.useHealthBedtime = useHealth
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
        await reminderService.rescheduleAllReminders(store: store, healthKit: healthKitService)
    }

    static let onboardingCompleteKey = "com.skincaretracker.onboardingComplete"

    static var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: onboardingCompleteKey)
    }
}

#Preview {
    let health = HealthKitService()
    OnboardingView(onComplete: {})
        .environmentObject(AppStore())
        .environmentObject(ReminderService())
        .environmentObject(health as HealthKitServiceBase)
}
