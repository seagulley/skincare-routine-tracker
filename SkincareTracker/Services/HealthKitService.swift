//
//  HealthKitService.swift
//  SkincareTracker
//
//  Reads sleep data from Health for bedtime and wake-up reminder scheduling.
//

import Foundation
import HealthKit

/// Fetches bedtime and wake time from Health app sleep data (in-bed samples).
final class HealthKitService: ObservableObject {
    private let healthStore = HKHealthStore()

    /// Whether HealthKit is available on this device.
    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Requests authorization to read sleep analysis. Call before fetching bedtime.
    func requestAuthorization() async throws {
        guard Self.isAvailable else { return }
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
    }

    /// Returns typical bedtime (hour and minute) from recent in-bed samples, or nil if unavailable.
    /// Uses the average of the last 7 nights' in-bed start times.
    func fetchTypicalBedtime() async -> (hour: Int, minute: Int)? {
        guard Self.isAvailable else { return nil }
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }

        let calendar = Calendar.current
        let now = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return nil }

        let predicate = HKQuery.predicateForSamples(withStart: weekAgo, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: 100,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard error == nil, let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }
                let bedtimes = samples
                    .filter { $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue }
                    .map { $0.startDate }
                let result = Self.averageBedtime(from: bedtimes, calendar: calendar)
                continuation.resume(returning: result)
            }
            healthStore.execute(query)
        }
    }

    /// Returns typical wake time (hour and minute) from recent in-bed samples, or nil if unavailable.
    /// Uses the average of the last 7 nights' in-bed end times (when user gets out of bed).
    func fetchTypicalWakeTime() async -> (hour: Int, minute: Int)? {
        guard Self.isAvailable else { return nil }
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }

        let calendar = Calendar.current
        let now = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return nil }

        let predicate = HKQuery.predicateForSamples(withStart: weekAgo, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: 100,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard error == nil, let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }
                let wakeTimes = samples
                    .filter { $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue }
                    .map { $0.endDate }
                let result = Self.averageTimeOfDay(from: wakeTimes, calendar: calendar)
                continuation.resume(returning: result)
            }
            healthStore.execute(query)
        }
    }

    private static func averageBedtime(from dates: [Date], calendar: Calendar) -> (hour: Int, minute: Int)? {
        averageTimeOfDay(from: dates, calendar: calendar)
    }

    private static func averageTimeOfDay(from dates: [Date], calendar: Calendar) -> (hour: Int, minute: Int)? {
        let components = dates.map { calendar.dateComponents([.hour, .minute], from: $0) }
        guard !components.isEmpty else { return nil }
        let totalMinutes = components.reduce(0) { acc, c in
            let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            return acc + m
        }
        let avg = totalMinutes / components.count
        return (avg / 60, avg % 60)
    }
}
