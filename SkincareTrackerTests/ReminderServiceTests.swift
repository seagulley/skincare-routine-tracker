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

        XCTAssertEqual(params.body, "Good morning, Here is your morning skincare routine: Cleanser, Serum. That's it.")
        XCTAssertEqual(params.title, "Morning Skincare")
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

        XCTAssertEqual(params.body, "Good morning, Here is your morning skincare routine: Moisturizer. That's it.")
        XCTAssertEqual(params.title, "Morning Skincare")
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

        XCTAssertEqual(params.body, "Good morning, Here is your morning skincare routine. That's it.")
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

        XCTAssertEqual(params.body, "Good night, Here is your night skincare routine: Cleanser, Retinol. That's it.")
        XCTAssertEqual(params.title, "Night Skincare")
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

        XCTAssertEqual(params.body, "Good night, Here is your night skincare routine. That's it.")
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
