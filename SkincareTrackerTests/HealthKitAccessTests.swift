//
//  HealthKitAccessTests.swift
//  SkincareTrackerTests
//
//  Verifies HealthKit authorization: onboarding Health sleep sync path, and Reminders
//  when "Use Health bedtime" / "Use Health wake time" are on. RemindersView uses hosting + mock continuation.
//

import XCTest
import SwiftUI
import UIKit
@testable import SkincareTracker

// MARK: - HealthKit Call Counting

private protocol HealthKitCallCounting: AnyObject {
    var requestAuthorizationCallCount: Int { get }
}

// MARK: - MockHealthKitService

/// Mock that records when requestAuthorization is called. Use in tests to verify Health access flow.
/// Supports awaiting the call via waitForAuthorizationCall() — no sleep or polling.
final class MockHealthKitService: HealthKitServiceBase, HealthKitCallCounting {
    var requestAuthorizationCallCount = 0

    private var continuation: CheckedContinuation<Void, Never>?

    override class var isAvailable: Bool { true }

    override func requestAuthorization() async throws {
        requestAuthorizationCallCount += 1
        continuation?.resume()
        continuation = nil
    }

    /// Suspends until requestAuthorization is called. CI-safe: no sleep or polling.
    func waitForAuthorizationCall() async {
        if requestAuthorizationCallCount >= 1 { return }
        await withCheckedContinuation { cont in
            continuation = cont
        }
    }

    override func fetchTypicalBedtime() async -> (hour: Int, minute: Int)? { nil }
    override func fetchTypicalWakeTime() async -> (hour: Int, minute: Int)? { nil }
}

/// Mock where HealthKit is unavailable (e.g. simulator without Health).
final class MockHealthKitServiceUnavailable: HealthKitServiceBase, HealthKitCallCounting {
    var requestAuthorizationCallCount = 0

    override class var isAvailable: Bool { false }

    override func requestAuthorization() async throws {
        requestAuthorizationCallCount += 1
    }

    override func fetchTypicalBedtime() async -> (hour: Int, minute: Int)? { nil }
    override func fetchTypicalWakeTime() async -> (hour: Int, minute: Int)? { nil }
}

/// Mock that throws when requestAuthorization is called. Use to verify graceful error handling.
final class MockHealthKitServiceThrowing: HealthKitServiceBase, HealthKitCallCounting {
    var requestAuthorizationCallCount = 0

    private var continuation: CheckedContinuation<Void, Never>?

    override class var isAvailable: Bool { true }

    override func requestAuthorization() async throws {
        requestAuthorizationCallCount += 1
        continuation?.resume()
        continuation = nil
        throw NSError(domain: "HealthKitAccessTests", code: -1, userInfo: [NSLocalizedDescriptionKey: "Health access denied"])
    }

    func waitForAuthorizationCall() async {
        if requestAuthorizationCallCount >= 1 { return }
        await withCheckedContinuation { cont in
            continuation = cont
        }
    }

    override func fetchTypicalBedtime() async -> (hour: Int, minute: Int)? { nil }
    override func fetchTypicalWakeTime() async -> (hour: Int, minute: Int)? { nil }
}

// MARK: - HealthKit Access Tests

@MainActor
final class HealthKitAccessTests: XCTestCase {

    var store: AppStore?
    var reminderService: ReminderService?
    var mockHealthKit: MockHealthKitService?

    override func setUpWithError() throws {
        store = AppStore()
        reminderService = ReminderService()
        mockHealthKit = MockHealthKitService()
    }

    override func tearDownWithError() throws {
        store = nil
        reminderService = nil
        mockHealthKit = nil
    }

    private func requireDependencies() throws -> (AppStore, ReminderService) {
        let s = try XCTUnwrap(store, "setUp failed to initialize store")
        let r = try XCTUnwrap(reminderService, "setUp failed to initialize reminderService")
        return (s, r)
    }

    /// Hosts RemindersView and runs the main loop until mock.requestAuthorizationCallCount >= 1 or timeout.
    /// Event-driven: breaks as soon as the mock is called. No fixed sleep.
    private func hostRemindersAndRunUntilAuthorized(mock: MockHealthKitService, view: some View, timeout: TimeInterval = 2) {
        let hosting = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 812))
        window.rootViewController = hosting
        window.makeKeyAndVisible()
        _ = hosting.view

        let deadline = Date().addingTimeInterval(timeout)
        while mock.requestAuthorizationCallCount < 1, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
    }

    /// Hosts RemindersView so onAppear fires. Caller must wait for completion (e.g. wait(for: expectation)).
    private func hostRemindersView(_ view: some View) {
        let hosting = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 812))
        window.rootViewController = hosting
        window.makeKeyAndVisible()
        _ = hosting.view
    }

    /// Hosts OnboardingView so onAppear fires. For unavailable HealthKit, run briefly; for available, waits for mock call.
    private func hostOnboardingView(_ view: some View) {
        let hosting = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 812))
        window.rootViewController = hosting
        window.makeKeyAndVisible()
        _ = hosting.view
    }

    // MARK: - Onboarding

    func testOnboarding_onAppear_doesNotTriggerHealthAuthorization() throws {
        let (store, reminderService) = try requireDependencies()
        let mock = MockHealthKitService()
        let view = OnboardingView(onComplete: {})
            .environmentObject(store)
            .environmentObject(reminderService)
            .environmentObject(mock as HealthKitServiceBase)

        hostOnboardingView(view)
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))

        XCTAssertEqual(
            mock.requestAuthorizationCallCount, 0,
            "Onboarding onAppear should NOT trigger Health access; only the button tap should"
        )
    }

    func testOnboarding_performHealthAuthorizationRequest_matchesHealthSleepSyncTogglePath() async throws {
        let mock = MockHealthKitService()
        await OnboardingView.performHealthAuthorizationRequest(healthKitService: mock)
        XCTAssertEqual(
            mock.requestAuthorizationCallCount, 1,
            "Same code path as enabling Sync with Health sleep schedule in onboarding"
        )
    }

    func testOnboarding_whenHealthUnavailable_doesNotTriggerRequestAuthorization() throws {
        let (store, reminderService) = try requireDependencies()
        let mock = MockHealthKitServiceUnavailable()
        let view = OnboardingView(onComplete: {})
            .environmentObject(store)
            .environmentObject(reminderService)
            .environmentObject(mock as HealthKitServiceBase)

        hostOnboardingView(view)
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))

        XCTAssertEqual(
            mock.requestAuthorizationCallCount, 0,
            "When HealthKit is unavailable, onboarding does not request Health (no Health sync toggle)"
        )
    }

    func testOnboarding_performHealthAuthorizationRequest_throwing_doesNotCrash() async throws {
        let mock = MockHealthKitServiceThrowing()
        await OnboardingView.performHealthAuthorizationRequest(healthKitService: mock)
        XCTAssertEqual(mock.requestAuthorizationCallCount, 1, "try? swallows throw; no crash")
    }

    // MARK: - Reminders - Use Health Bedtime / Wake Time

    func testReminders_toggleUseHealthBedtime_triggersRequestAuthorization() async throws {
        let (store, reminderService) = try requireDependencies()
        let mock = MockHealthKitService()
        var nightConfig = store.reminderConfig(for: .night)
        nightConfig.isEnabled = true
        nightConfig.useHealthBedtime = true
        store.updateReminderConfig(nightConfig)

        let view = RemindersView()
            .environmentObject(store)
            .environmentObject(reminderService)
            .environmentObject(mock as HealthKitServiceBase)

        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                self.hostRemindersAndRunUntilAuthorized(mock: mock, view: view)
            }
            group.addTask {
                await mock.waitForAuthorizationCall()
            }
        }

        XCTAssertEqual(
            mock.requestAuthorizationCallCount, 1,
            "RemindersView onAppear with useHealthBedtime=true should trigger Health access exactly once"
        )
    }

    func testReminders_toggleUseHealthWakeTime_triggersRequestAuthorization() async throws {
        let (store, reminderService) = try requireDependencies()
        let mock = MockHealthKitService()
        var morningConfig = store.reminderConfig(for: .morning)
        morningConfig.isEnabled = true
        morningConfig.useHealthWakeTime = true
        store.updateReminderConfig(morningConfig)

        let view = RemindersView()
            .environmentObject(store)
            .environmentObject(reminderService)
            .environmentObject(mock as HealthKitServiceBase)

        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                self.hostRemindersAndRunUntilAuthorized(mock: mock, view: view)
            }
            group.addTask {
                await mock.waitForAuthorizationCall()
            }
        }

        XCTAssertEqual(
            mock.requestAuthorizationCallCount, 1,
            "RemindersView onAppear with useHealthWakeTime=true should trigger Health access exactly once"
        )
    }

    func testReminders_withoutHealthOptions_doesNotTriggerRequestAuthorization() throws {
        let (store, reminderService) = try requireDependencies()
        let mock = MockHealthKitService()
        let didComplete = expectation(description: "rescheduleReminders completed")
        let view = RemindersView()
            .environmentObject(store)
            .environmentObject(reminderService)
            .environmentObject(mock as HealthKitServiceBase)
            .environment(\.reminderRescheduleComplete, { didComplete.fulfill() })

        hostRemindersView(view)
        // Reschedule walks a multi-day horizon and registers many non-repeating notifications; 2s is too tight on CI.
        wait(for: [didComplete], timeout: 60)

        XCTAssertEqual(
            mock.requestAuthorizationCallCount, 0,
            "When Health bedtime/wake options are off, requestAuthorization should not be called"
        )
    }
}
