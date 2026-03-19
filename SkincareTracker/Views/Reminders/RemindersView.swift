//
//  RemindersView.swift
//  SkincareTracker
//

import SwiftUI

struct RemindersView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var reminderService: ReminderService
    @EnvironmentObject var healthKitService: HealthKitService

    var body: some View {
        NavigationStack {
            List {
                ForEach(RoutineType.allCases, id: \.self) { type in
                    ReminderRowView(
                        config: store.reminderConfig(for: type),
                        healthKitAvailable: HealthKitService.isAvailable,
                        onSave: { config in
                            store.updateReminderConfig(config)
                            Task { await rescheduleReminders() }
                        }
                    )
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("Reminders")
            .listStyle(.insetGrouped)
            .onAppear {
                Task { await rescheduleReminders() }
            }
        }
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
}

struct ReminderRowView: View {
    let config: ReminderConfig
    let healthKitAvailable: Bool
    let onSave: (ReminderConfig) -> Void

    @State private var isEnabled: Bool
    @State private var hour: Int
    @State private var minute: Int
    @State private var useHealthWakeTime: Bool
    @State private var useHealthBedtime: Bool
    @State private var showTimePicker = false

    init(config: ReminderConfig, healthKitAvailable: Bool, onSave: @escaping (ReminderConfig) -> Void) {
        self.config = config
        self.healthKitAvailable = healthKitAvailable
        self.onSave = onSave
        _isEnabled = State(initialValue: config.isEnabled)
        _hour = State(initialValue: config.hour)
        _minute = State(initialValue: config.minute)
        _useHealthWakeTime = State(initialValue: config.useHealthWakeTime)
        _useHealthBedtime = State(initialValue: config.useHealthBedtime)
    }

    private var isMorningRoutine: Bool { config.routineType == .morning }
    private var isNightRoutine: Bool { config.routineType == .night }

    var body: some View {
        Section {
            Toggle("Enabled", isOn: $isEnabled)
                .tint(.green)
                .onChange(of: isEnabled) { _, _ in saveConfig() }
                .listRowBackground(AppColors.rowBackground)

            if isMorningRoutine, healthKitAvailable {
                Toggle("Use Health wake time", isOn: $useHealthWakeTime)
                    .tint(.green)
                    .onChange(of: useHealthWakeTime) { _, _ in saveConfig() }
                    .listRowBackground(AppColors.rowBackground)
            }
            if isNightRoutine, healthKitAvailable {
                Toggle("Use Health bedtime", isOn: $useHealthBedtime)
                    .tint(.green)
                    .onChange(of: useHealthBedtime) { _, _ in saveConfig() }
                    .listRowBackground(AppColors.rowBackground)
            }

            if useHealthWakeTime && isMorningRoutine {
                HStack {
                    Text("Time")
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Text("When you wake up")
                        .foregroundStyle(AppColors.textSecondary)
                }
                .listRowBackground(AppColors.rowBackground)
            } else if useHealthBedtime && isNightRoutine {
                HStack {
                    Text("Time")
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Text("1 hour before bedtime")
                        .foregroundStyle(AppColors.textSecondary)
                }
                .listRowBackground(AppColors.rowBackground)
            } else {
                Button {
                    showTimePicker = true
                } label: {
                    HStack {
                        Text("Time")
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        Text(String(format: "%d:%02d", hour, minute))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .disabled(!isEnabled)
                .listRowBackground(AppColors.rowBackground)
            }
        } header: {
            Text(config.routineType.rawValue + " Routine")
                .foregroundStyle(AppColors.sectionHeader)
        } footer: {
            if healthKitAvailable && useHealthWakeTime && isMorningRoutine {
                Text("Reminder fires when your Health sleep routine ends (when you wake up).")
                    .foregroundStyle(AppColors.textSecondary)
            } else if healthKitAvailable && useHealthBedtime && isNightRoutine {
                Text("Reminder fires 1 hour before your typical bedtime from the Health app.")
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                Text("You'll be reminded which products to apply for your \(config.routineType.rawValue.lowercased()) routine.")
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .onChange(of: hour) { _, _ in saveConfig() }
        .onChange(of: minute) { _, _ in saveConfig() }
        .sheet(isPresented: $showTimePicker) {
            TimePickerSheet(
                hour: $hour,
                minute: $minute,
                onDismiss: { showTimePicker = false }
            )
        }
    }

    private func saveConfig() {
        var newConfig = config
        newConfig.isEnabled = isEnabled
        newConfig.hour = hour
        newConfig.minute = minute
        newConfig.useHealthWakeTime = useHealthWakeTime
        newConfig.useHealthBedtime = useHealthBedtime
        onSave(newConfig)
    }
}

struct TimePickerSheet: View {
    @Binding var hour: Int
    @Binding var minute: Int
    let onDismiss: () -> Void

    private var date: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = hour
                components.minute = minute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                hour = components.hour ?? 0
                minute = components.minute ?? 0
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Time", selection: date, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .listRowBackground(AppColors.rowBackground)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("Reminder Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    RemindersView()
        .environmentObject(AppStore())
        .environmentObject(ReminderService())
        .environmentObject(HealthKitService())
}
