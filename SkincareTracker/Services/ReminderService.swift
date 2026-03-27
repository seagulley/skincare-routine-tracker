//
//  ReminderService.swift
//  SkincareTracker
//
//  Schedules local notifications with the user's skincare routine.
//

import Foundation
import UserNotifications

/// Builds and schedules skincare routine reminders.
@MainActor
final class ReminderService: ObservableObject {
    private let center = UNUserNotificationCenter.current()

    static let reminderHorizonDays = 60

    static let reminderRequestIdentifierPrefix = "skincare.routine."

    private static let lastRollForwardDayKey = "com.skincaretracker.lastReminderRollForwardDay"

    struct PlannedReminderEntry {
        let identifier: String
        let title: String
        let body: String
        let noRoutine: Bool
        let dateComponents: DateComponents
        let repeats: Bool
    }

    /// Computes pending notifications for the horizon. Used by `rescheduleReminders` and tests to ensure each day’s body matches that day’s cycle (morning and night).
    static func plannedReminderEntries(
        configs: [ReminderConfig],
        productsForDate: (Date, RoutineType) -> [Product],
        healthWakeTime: (hour: Int, minute: Int)?,
        healthBedtime: (hour: Int, minute: Int)?,
        todayStart: Date,
        now: Date,
        calendar: Calendar,
        horizonDays: Int
    ) -> [PlannedReminderEntry] {
        var entries: [PlannedReminderEntry] = []
        for dayOffset in 0..<horizonDays {
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: todayStart) else { continue }
            for config in configs where config.isEnabled {
                let products = productsForDate(dayDate, config.routineType)
                let params = Self.buildNotificationParameters(
                    config: config,
                    products: products,
                    healthWakeTime: healthWakeTime,
                    healthBedtime: healthBedtime
                )
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: dayDate)
                dateComponents.hour = params.hour
                dateComponents.minute = params.minute
                guard let fireDate = calendar.date(from: dateComponents), fireDate > now else { continue }

                let identifier = Self.reminderRequestIdentifier(routineType: config.routineType, dayStart: dayDate, calendar: calendar)
                entries.append(
                    PlannedReminderEntry(
                        identifier: identifier,
                        title: params.title,
                        body: params.body,
                        noRoutine: products.isEmpty,
                        dateComponents: dateComponents,
                        repeats: false
                    )
                )
            }
        }
        return entries
    }

    /// Request notification permission. Call before scheduling.
    func requestPermission() async -> Bool {
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized { return true }
        let env = ProcessInfo.processInfo.environment
        // GitHub Actions and XCTest runs have no one to tap the system alert; requestAuthorization can block until timeout.
        if env["CI"] == "true" || env["XCTestConfigurationFilePath"] != nil {
            return false
        }
        let granted = try? await center.requestAuthorization(options: [.alert, .sound])
        return granted ?? false
    }

    /// Fetches Health sleep times when enabled and reschedules local notifications.
    func rescheduleAllReminders(store: AppStore, healthKit: HealthKitServiceBase) async {
        var healthWakeTime: (hour: Int, minute: Int)?
        var healthBedtime: (hour: Int, minute: Int)?
        let morningConfig = store.reminderConfig(for: .morning)
        let nightConfig = store.reminderConfig(for: .night)
        if (morningConfig.useHealthWakeTime && morningConfig.isEnabled) || (nightConfig.useHealthBedtime && nightConfig.isEnabled) {
            try? await healthKit.requestAuthorization()
            if morningConfig.useHealthWakeTime, morningConfig.isEnabled {
                healthWakeTime = await healthKit.fetchTypicalWakeTime()
            }
            if nightConfig.useHealthBedtime, nightConfig.isEnabled {
                healthBedtime = await healthKit.fetchTypicalBedtime()
            }
        }
        await rescheduleReminders(
            configs: store.reminderConfigs,
            productsForDate: { store.productsForDate($0, routineType: $1) },
            healthWakeTime: healthWakeTime,
            healthBedtime: healthBedtime
        )
    }

    /// Reschedules once per calendar day when the app becomes active so the rolling window stays ahead of the clock.
    func rollRemindersForwardIfNeeded(store: AppStore, healthKit: HealthKitServiceBase) async {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let fmt = DateFormatter()
        fmt.calendar = calendar
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = calendar.timeZone
        fmt.dateFormat = "yyyy-MM-dd"
        let dayKey = fmt.string(from: todayStart)
        if UserDefaults.standard.string(forKey: Self.lastRollForwardDayKey) == dayKey { return }
        guard store.reminderConfigs.contains(where: \.isEnabled) else { return }
        guard await requestPermission() else { return }
        await rescheduleAllReminders(store: store, healthKit: healthKit)
        UserDefaults.standard.set(dayKey, forKey: Self.lastRollForwardDayKey)
    }

    /// Clears pending skincare reminders and schedules one non-repeating notification per day in the horizon for each enabled routine.
    func rescheduleReminders(
        configs: [ReminderConfig],
        productsForDate: (Date, RoutineType) -> [Product],
        healthWakeTime: (hour: Int, minute: Int)?,
        healthBedtime: (hour: Int, minute: Int)?
    ) async {
        await removePendingSkincareRoutineReminders()
        guard await requestPermission() else { return }

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let now = Date()
        let planned = Self.plannedReminderEntries(
            configs: configs,
            productsForDate: productsForDate,
            healthWakeTime: healthWakeTime,
            healthBedtime: healthBedtime,
            todayStart: todayStart,
            now: now,
            calendar: calendar,
            horizonDays: Self.reminderHorizonDays
        )
        for entry in planned {
            let content = UNMutableNotificationContent()
            content.title = entry.title
            content.body = entry.body
            content.sound = .default
            if entry.noRoutine {
                content.userInfo = ["noRoutine": true]
            }
            let trigger = UNCalendarNotificationTrigger(dateMatching: entry.dateComponents, repeats: entry.repeats)
            let request = UNNotificationRequest(
                identifier: entry.identifier,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    private func removePendingSkincareRoutineReminders() async {
        let pending = await withCheckedContinuation { (cont: CheckedContinuation<[UNNotificationRequest], Never>) in
            center.getPendingNotificationRequests { cont.resume(returning: $0) }
        }
        var ids = pending.map(\.identifier).filter { $0.hasPrefix(Self.reminderRequestIdentifierPrefix) }
        ids.append(contentsOf: ["morning", "night"])
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Stable per-day identifier for a routine reminder (used instead of repeating `morning` / `night` ids).
    static func reminderRequestIdentifier(routineType: RoutineType, dayStart: Date, calendar: Calendar) -> String {
        let day = calendar.startOfDay(for: dayStart)
        let fmt = DateFormatter()
        fmt.calendar = calendar
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = calendar.timeZone
        fmt.dateFormat = "yyyy-MM-dd"
        let tag = routineType == .morning ? "morning" : "night"
        return "\(reminderRequestIdentifierPrefix)\(tag).\(fmt.string(from: day))"
    }

    /// Builds notification parameters (body, title, hour, minute) for testing.
    internal static func buildNotificationParameters(
        config: ReminderConfig,
        products: [Product],
        healthWakeTime: (hour: Int, minute: Int)?,
        healthBedtime: (hour: Int, minute: Int)?
    ) -> (body: String, title: String, hour: Int, minute: Int, identifier: String) {
        let body: String
        if products.isEmpty {
            body = config.routineType == .morning
                ? "No skincare routine for this morning! Set up a routine in the app."
                : "No skincare routine for tonight! Set up a routine in the app."
        } else {
            body = products.map(\.name).joined(separator: " > ") + "."
        }
        let title = "\(config.routineType.rawValue) Skincare Routine"

        let hour: Int
        let minute: Int
        if config.routineType == .morning, config.useHealthWakeTime, let wake = healthWakeTime {
            hour = wake.hour
            minute = wake.minute
        } else if config.routineType == .night, config.useHealthBedtime, let bed = healthBedtime {
            let totalMins = bed.hour * 60 + bed.minute
            let reminderMins = max(0, totalMins - 60)
            hour = reminderMins / 60
            minute = reminderMins % 60
        } else {
            hour = config.hour
            minute = config.minute
        }

        let identifier = config.routineType == .morning ? "morning" : "night"
        return (body, title, hour, minute, identifier)
    }
}
