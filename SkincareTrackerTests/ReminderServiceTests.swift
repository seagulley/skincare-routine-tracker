//
//  ReminderServiceTests.swift
//  SkincareTrackerTests
//

import XCTest
@testable import SkincareTracker

@MainActor
final class ReminderServiceTests: XCTestCase {

    // MARK: - Notification Content (buildNotificationParameters)

    func testBuildNotificationParameters_morningWithProducts() throws {
        let config = ReminderConfig(routineType: .morning, hour: 8, minute: 30, isEnabled: true)
        let products = [Product(name: "Cleanser"), Product(name: "Serum")]

        let params = ReminderService.buildNotificationParameters(
            config: config,
            products: products,
            healthWakeTime: nil,
            healthBedtime: nil
        )

        XCTAssertEqual(params.body, "Cleanser > Serum.")
        XCTAssertEqual(params.title, "Morning Skincare Routine")
        XCTAssertEqual(params.hour, 8)
        XCTAssertEqual(params.minute, 30)
        XCTAssertEqual(params.identifier, "morning")
    }

    func testBuildNotificationParameters_morningWithoutName() throws {
        let config = ReminderConfig(routineType: .morning, hour: 7, minute: 0, isEnabled: true)
        let products = [Product(name: "Moisturizer")]

        let params = ReminderService.buildNotificationParameters(
            config: config,
            products: products,
            healthWakeTime: nil,
            healthBedtime: nil
        )

        XCTAssertEqual(params.body, "Moisturizer.")
        XCTAssertEqual(params.title, "Morning Skincare Routine")
        XCTAssertEqual(params.hour, 7)
        XCTAssertEqual(params.minute, 0)
    }

    func testBuildNotificationParameters_morningEmptyRoutine() throws {
        let config = ReminderConfig(routineType: .morning, hour: 8, minute: 0, isEnabled: true)

        let params = ReminderService.buildNotificationParameters(
            config: config,
            products: [],
            healthWakeTime: nil,
            healthBedtime: nil
        )

        XCTAssertEqual(params.body, "No skincare routine for this morning! Set up a routine in the app.")
        XCTAssertEqual(params.hour, 8)
        XCTAssertEqual(params.minute, 0)
    }

    func testBuildNotificationParameters_nightWithNameAndProducts() throws {
        let config = ReminderConfig(routineType: .night, hour: 21, minute: 0, isEnabled: true)
        let products = [Product(name: "Cleanser"), Product(name: "Retinol")]

        let params = ReminderService.buildNotificationParameters(
            config: config,
            products: products,
            healthWakeTime: nil,
            healthBedtime: nil
        )

        XCTAssertEqual(params.body, "Cleanser > Retinol.")
        XCTAssertEqual(params.title, "Night Skincare Routine")
        XCTAssertEqual(params.hour, 21)
        XCTAssertEqual(params.minute, 0)
        XCTAssertEqual(params.identifier, "night")
    }

    // MARK: - Health Bedtime

    func testBuildNotificationParameters_nightWithHealthBedtime_usesOneHourBefore() throws {
        let config = ReminderConfig(
            routineType: .night,
            hour: 21,
            minute: 0,
            isEnabled: true,
            useHealthBedtime: true
        )
        let products: [Product] = []

        let params = ReminderService.buildNotificationParameters(
            config: config,
            products: products,
            healthWakeTime: nil,
            healthBedtime: (hour: 22, minute: 30)
        )

        XCTAssertEqual(params.body, "No skincare routine for tonight! Set up a routine in the app.")
        XCTAssertEqual(params.hour, 21)
        XCTAssertEqual(params.minute, 30, "22:30 - 1hr = 21:30")
    }

    func testBuildNotificationParameters_nightWithHealthBedtime_bedtimeMidnight() throws {
        let config = ReminderConfig(
            routineType: .night,
            hour: 21,
            minute: 0,
            isEnabled: true,
            useHealthBedtime: true
        )

        let params = ReminderService.buildNotificationParameters(
            config: config,
            products: [],
            healthWakeTime: nil,
            healthBedtime: (hour: 0, minute: 30)
        )

        // 0:30 = 30 mins; 30 - 60 = -30; max(0, -30) = 0 → 0:00
        XCTAssertEqual(params.hour, 0)
        XCTAssertEqual(params.minute, 0)
    }

    func testBuildNotificationParameters_nightWithHealthBedtimeNil_fallsBackToManualTime() throws {
        let config = ReminderConfig(
            routineType: .night,
            hour: 20,
            minute: 45,
            isEnabled: true,
            useHealthBedtime: true
        )

        let params = ReminderService.buildNotificationParameters(
            config: config,
            products: [],
            healthWakeTime: nil,
            healthBedtime: nil
        )

        XCTAssertEqual(params.hour, 20)
        XCTAssertEqual(params.minute, 45)
    }

    func testBuildNotificationParameters_nightWithoutHealthBedtime_usesManualTime() throws {
        let config = ReminderConfig(
            routineType: .night,
            hour: 21,
            minute: 15,
            isEnabled: true,
            useHealthBedtime: false
        )

        let params = ReminderService.buildNotificationParameters(
            config: config,
            products: [],
            healthWakeTime: nil,
            healthBedtime: (hour: 23, minute: 0)
        )

        XCTAssertEqual(params.hour, 21)
        XCTAssertEqual(params.minute, 15, "Should use config time when useHealthBedtime is false")
    }

    func testBuildNotificationParameters_morningWithHealthWakeTimeFalse_usesManualTime() throws {
        let config = ReminderConfig(
            routineType: .morning,
            hour: 8,
            minute: 0,
            isEnabled: true,
            useHealthWakeTime: false
        )

        let params = ReminderService.buildNotificationParameters(
            config: config,
            products: [],
            healthWakeTime: (hour: 7, minute: 30),
            healthBedtime: nil
        )

        XCTAssertEqual(params.hour, 8)
        XCTAssertEqual(params.minute, 0, "Morning uses manual time when useHealthWakeTime is false")
    }

    func testBuildNotificationParameters_morningWithHealthWakeTime_usesWakeTime() throws {
        let config = ReminderConfig(
            routineType: .morning,
            hour: 8,
            minute: 0,
            isEnabled: true,
            useHealthWakeTime: true
        )

        let params = ReminderService.buildNotificationParameters(
            config: config,
            products: [],
            healthWakeTime: (hour: 7, minute: 30),
            healthBedtime: nil
        )

        XCTAssertEqual(params.hour, 7)
        XCTAssertEqual(params.minute, 30, "Morning uses Health wake time when useHealthWakeTime is true")
    }

    // MARK: - Per-calendar-day bodies (cycle day advances; morning & night)

    /// Fixed clock + calendar so planned fire times are stable. Morning 08:00 and night 21:00; `now` is day 0 at 06:00 so the first two days schedule.
    private func makeFixedCalendarAndAnchors() -> (calendar: Calendar, todayStart: Date, day1: Date, now: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let todayStart = calendar.date(from: DateComponents(year: 2020, month: 6, day: 15))!
        let day1 = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        let now = calendar.date(byAdding: .hour, value: 6, to: todayStart)!
        return (calendar, todayStart, day1, now)
    }

    /// Returns different product names per calendar day and routine so we can detect “frozen day 0” bugs.
    private func productsForDateCycleStub(
        calendar: Calendar,
        todayStart: Date,
        day1: Date,
        date: Date,
        routineType: RoutineType
    ) -> [Product] {
        let day = calendar.startOfDay(for: date)
        switch (day, routineType) {
        case (todayStart, .morning):
            return [Product(name: "AM-Day0")]
        case (todayStart, .night):
            return [Product(name: "PM-Day0")]
        case (day1, .morning):
            return [Product(name: "AM-Day1")]
        case (day1, .night):
            return [Product(name: "PM-Day1")]
        default:
            return []
        }
    }

    func testPlannedReminderEntries_morningAndNightUseProductsForEachCalendarDay() {
        let (calendar, todayStart, day1, now) = makeFixedCalendarAndAnchors()
        let morningConfig = ReminderConfig(routineType: .morning, hour: 8, minute: 0, isEnabled: true)
        let nightConfig = ReminderConfig(routineType: .night, hour: 21, minute: 0, isEnabled: true)
        let configs = [morningConfig, nightConfig]

        let productsForDate: (Date, RoutineType) -> [Product] = { date, routineType in
            self.productsForDateCycleStub(calendar: calendar, todayStart: todayStart, day1: day1, date: date, routineType: routineType)
        }

        let entries = ReminderService.plannedReminderEntries(
            configs: configs,
            productsForDate: productsForDate,
            healthWakeTime: nil,
            healthBedtime: nil,
            todayStart: todayStart,
            now: now,
            calendar: calendar,
            horizonDays: 2
        )

        let idM0 = ReminderService.reminderRequestIdentifier(routineType: .morning, dayStart: todayStart, calendar: calendar)
        let idN0 = ReminderService.reminderRequestIdentifier(routineType: .night, dayStart: todayStart, calendar: calendar)
        let idM1 = ReminderService.reminderRequestIdentifier(routineType: .morning, dayStart: day1, calendar: calendar)
        let idN1 = ReminderService.reminderRequestIdentifier(routineType: .night, dayStart: day1, calendar: calendar)

        guard let m0 = entries.first(where: { $0.identifier == idM0 }),
              let n0 = entries.first(where: { $0.identifier == idN0 }),
              let m1 = entries.first(where: { $0.identifier == idM1 }),
              let n1 = entries.first(where: { $0.identifier == idN1 }) else {
            XCTFail("Expected four entries for two days × morning & night; got: \(entries.map(\.identifier))")
            return
        }

        let expectedM0 = ReminderService.buildNotificationParameters(
            config: morningConfig,
            products: productsForDate(todayStart, .morning),
            healthWakeTime: nil,
            healthBedtime: nil
        ).body
        let expectedN0 = ReminderService.buildNotificationParameters(
            config: nightConfig,
            products: productsForDate(todayStart, .night),
            healthWakeTime: nil,
            healthBedtime: nil
        ).body
        let expectedM1 = ReminderService.buildNotificationParameters(
            config: morningConfig,
            products: productsForDate(day1, .morning),
            healthWakeTime: nil,
            healthBedtime: nil
        ).body
        let expectedN1 = ReminderService.buildNotificationParameters(
            config: nightConfig,
            products: productsForDate(day1, .night),
            healthWakeTime: nil,
            healthBedtime: nil
        ).body

        XCTAssertEqual(m0.body, expectedM0)
        XCTAssertEqual(n0.body, expectedN0)
        XCTAssertEqual(m1.body, expectedM1)
        XCTAssertEqual(n1.body, expectedN1)

        XCTAssertEqual(m0.repeats, false)
        XCTAssertEqual(n0.repeats, false)
        XCTAssertNotEqual(expectedM0, expectedM1, "fixture: day 0 and day 1 morning must differ")
        XCTAssertNotEqual(expectedN0, expectedN1, "fixture: day 0 and day 1 night must differ")
    }

    /// Regression: the old implementation used `productsForDate(todayStart, …)` for the notification body with a *repeating* trigger, so day 2 of the cycle still showed day 1’s product list. Planned entries for day 1 must not match bodies derived only from `todayStart`.
    func testPlannedReminderEntries_day1BodiesDifferFromFrozenTodayStartBodies() {
        let (calendar, todayStart, day1, now) = makeFixedCalendarAndAnchors()
        let morningConfig = ReminderConfig(routineType: .morning, hour: 8, minute: 0, isEnabled: true)
        let nightConfig = ReminderConfig(routineType: .night, hour: 21, minute: 0, isEnabled: true)

        let productsForDate: (Date, RoutineType) -> [Product] = { date, routineType in
            self.productsForDateCycleStub(calendar: calendar, todayStart: todayStart, day1: day1, date: date, routineType: routineType)
        }

        let frozenTodayMorningBody = ReminderService.buildNotificationParameters(
            config: morningConfig,
            products: productsForDate(todayStart, .morning),
            healthWakeTime: nil,
            healthBedtime: nil
        ).body
        let frozenTodayNightBody = ReminderService.buildNotificationParameters(
            config: nightConfig,
            products: productsForDate(todayStart, .night),
            healthWakeTime: nil,
            healthBedtime: nil
        ).body

        let entries = ReminderService.plannedReminderEntries(
            configs: [morningConfig, nightConfig],
            productsForDate: productsForDate,
            healthWakeTime: nil,
            healthBedtime: nil,
            todayStart: todayStart,
            now: now,
            calendar: calendar,
            horizonDays: 2
        )

        let idM1 = ReminderService.reminderRequestIdentifier(routineType: .morning, dayStart: day1, calendar: calendar)
        let idN1 = ReminderService.reminderRequestIdentifier(routineType: .night, dayStart: day1, calendar: calendar)
        let m1 = entries.first { $0.identifier == idM1 }
        let n1 = entries.first { $0.identifier == idN1 }

        XCTAssertNotEqual(m1?.body, frozenTodayMorningBody, "Day 1 morning notification must not reuse day 0’s product list.")
        XCTAssertNotEqual(n1?.body, frozenTodayNightBody, "Day 1 night notification must not reuse day 0’s product list.")
    }

    /// The pre-fix design scheduled only two repeating requests (`morning` / `night`), so the body never updated. We require one non-repeating request per calendar day per routine.
    func testPlannedReminderEntries_twoCalendarDaysScheduleFourNonRepeatingRequests() {
        let (calendar, todayStart, day1, now) = makeFixedCalendarAndAnchors()
        let morningConfig = ReminderConfig(routineType: .morning, hour: 8, minute: 0, isEnabled: true)
        let nightConfig = ReminderConfig(routineType: .night, hour: 21, minute: 0, isEnabled: true)
        let productsForDate: (Date, RoutineType) -> [Product] = { date, routineType in
            self.productsForDateCycleStub(calendar: calendar, todayStart: todayStart, day1: day1, date: date, routineType: routineType)
        }

        let entries = ReminderService.plannedReminderEntries(
            configs: [morningConfig, nightConfig],
            productsForDate: productsForDate,
            healthWakeTime: nil,
            healthBedtime: nil,
            todayStart: todayStart,
            now: now,
            calendar: calendar,
            horizonDays: 2
        )

        XCTAssertEqual(entries.count, 4, "Expected 2 days × 2 routines")
        XCTAssertTrue(entries.allSatisfy { !$0.repeats })
        let ids = Set(entries.map(\.identifier))
        XCTAssertEqual(ids.count, 4, "Each scheduled notification should have a unique identifier")
    }

    // MARK: - Integration-style (rescheduleReminders doesn't crash)

    func testRescheduleReminders_withDisabledConfigs_doesNotThrow() async throws {
        let service = ReminderService()
        let configs = [
            ReminderConfig(routineType: .morning, hour: 8, minute: 0, isEnabled: false),
            ReminderConfig(routineType: .night, hour: 21, minute: 0, isEnabled: false)
        ]

        await service.rescheduleReminders(
            configs: configs,
            productsForDate: { _, _ in [] },
            healthWakeTime: nil,
            healthBedtime: nil
        )
    }
}
