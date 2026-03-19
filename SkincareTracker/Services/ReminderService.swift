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

    /// Request notification permission. Call before scheduling.
    func requestPermission() async -> Bool {
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized { return true }
        let granted = try? await center.requestAuthorization(options: [.alert, .sound])
        return granted ?? false
    }

    /// Clears all pending skincare reminders and reschedules based on config and store.
    func rescheduleReminders(
        configs: [ReminderConfig],
        productsForDate: (Date, RoutineType) -> [Product],
        healthWakeTime: (hour: Int, minute: Int)?,
        healthBedtime: (hour: Int, minute: Int)?
    ) async {
        center.removePendingNotificationRequests(withIdentifiers: ["morning", "night"])
        guard await requestPermission() else { return }

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        for config in configs where config.isEnabled {
            let products = productsForDate(todayStart, config.routineType)
            let params = Self.buildNotificationParameters(
                config: config,
                products: products,
                healthWakeTime: healthWakeTime,
                healthBedtime: healthBedtime
            )
            let content = UNMutableNotificationContent()
            content.title = params.title
            content.body = params.body
            content.sound = .default
            if products.isEmpty {
                content.userInfo = ["noRoutine": true]
            }
            var dateComponents = DateComponents()
            dateComponents.hour = params.hour
            dateComponents.minute = params.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: params.identifier,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
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
