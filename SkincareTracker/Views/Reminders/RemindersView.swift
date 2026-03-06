//
//  RemindersView.swift
//  SkincareTracker
//

import SwiftUI

struct RemindersView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(RoutineType.allCases, id: \.self) { type in
                    ReminderRowView(
                        config: store.reminderConfig(for: type),
                        onSave: { config in
                            store.updateReminderConfig(config)
                        }
                    )
                }
            }
            .navigationTitle("Reminders")
            .listStyle(.insetGrouped)
        }
    }
}

struct ReminderRowView: View {
    let config: ReminderConfig
    let onSave: (ReminderConfig) -> Void
    
    @State private var isEnabled: Bool
    @State private var hour: Int
    @State private var minute: Int
    @State private var showTimePicker = false
    
    init(config: ReminderConfig, onSave: @escaping (ReminderConfig) -> Void) {
        self.config = config
        self.onSave = onSave
        _isEnabled = State(initialValue: config.isEnabled)
        _hour = State(initialValue: config.hour)
        _minute = State(initialValue: config.minute)
    }
    
    var body: some View {
        Section {
            Toggle("Enabled", isOn: $isEnabled)
                .onChange(of: isEnabled) { _, _ in saveConfig() }
            
            Button {
                showTimePicker = true
            } label: {
                HStack {
                    Text("Time")
                    Spacer()
                    Text(String(format: "%d:%02d", hour, minute))
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!isEnabled)
        } header: {
            Text(config.routineType.rawValue + " Routine")
        } footer: {
            Text("You'll be reminded which products to apply for your \(config.routineType.rawValue.lowercased()) routine.")
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
        onSave(newConfig)
    }
}

struct TimePickerSheet: View {
    @Binding var hour: Int
    @Binding var minute: Int
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Hour: \(hour)", value: $hour, in: 0...23)
                    Stepper("Minute: \(minute)", value: $minute, in: 0...59)
                }
            }
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
}
