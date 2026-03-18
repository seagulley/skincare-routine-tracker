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
        let routineLabel = config.routineType.rawValue.lowercased()
        let greeting = config.routineType == .morning ? "Good morning" : "Good night"
        let productList = products.map(\.name).joined(separator: ", ")
        let routinePart = productList.isEmpty
            ? "Here is your \(routineLabel) skincare routine."
            : "Here is your \(routineLabel) skincare routine: \(productList)."
        let body = "\(greeting), \(routinePart) That's it."
        let title = "\(config.routineType.rawValue) Skincare"

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
