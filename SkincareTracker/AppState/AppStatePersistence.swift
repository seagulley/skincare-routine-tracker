//
//  AppStatePersistence.swift
//  SkincareTracker
//
//  Persists app state to disk so data survives app exit.
//

import Foundation

/// Codable snapshot of app state for persistence.
/// Uses string keys for UUIDs where JSON requires string keys.
private struct PersistedState: Codable {
    var products: [Product]
    var routines: [Routine]
    var cycleProductColors: [String: Int]  // uuidString -> palette index
    var cycleProductOrder: [String]        // uuidStrings in order
    var cycleAssignments: [String: [String]]  // "dayIndex-RoutineType" -> [uuidStrings]
    var cycleStartDate: Date?
    var cycleLength: Int
    var putOffRecords: [PutOffRecordCodable]
    var reminderConfigs: [ReminderConfig]
}

private struct PutOffRecordCodable: Codable {
    let productId: UUID
    let dayString: String
    let routineType: RoutineType
}

/// State loaded from disk, ready to apply to AppStore.
struct LoadedAppState {
    var products: Set<Product>
    var routines: [Routine]
    var cycleProductColors: [UUID: Int]
    var cycleProductOrder: [UUID]
    var cycleAssignments: [String: Set<UUID>]
    var cycleStartDate: Date?
    var cycleLength: Int
    var putOffRecords: [(productId: UUID, dayString: String, routineType: RoutineType)]
    var reminderConfigs: [ReminderConfig]
}

enum AppStatePersistence {
    private static let fileName = "app_state.json"

    /// Override for tests to use a temp directory. Set in test setUp, clear in tearDown.
    static var fileURLOverride: URL?

    static var fileURL: URL {
        if let override = fileURLOverride { return override }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
    }

    /// Loads persisted state from disk. Returns nil if file doesn't exist or decoding fails.
    static func load() -> LoadedAppState? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let persisted = try? JSONDecoder().decode(PersistedState.self, from: data) else { return nil }
        return LoadedAppState(
            products: Set(persisted.products),
            routines: persisted.routines,
            cycleProductColors: Dictionary(uniqueKeysWithValues: persisted.cycleProductColors.compactMap { key, value in
                guard let uuid = UUID(uuidString: key) else { return nil }
                return (uuid, value)
            }),
            cycleProductOrder: persisted.cycleProductOrder.compactMap { UUID(uuidString: $0) },
            cycleAssignments: Dictionary(uniqueKeysWithValues: persisted.cycleAssignments.map { key, uuids in
                (key, Set(uuids.compactMap { UUID(uuidString: $0) }))
            }),
            cycleStartDate: persisted.cycleStartDate,
            cycleLength: persisted.cycleLength,
            putOffRecords: persisted.putOffRecords.map { ($0.productId, $0.dayString, $0.routineType) },
            reminderConfigs: persisted.reminderConfigs
        )
    }

    /// Saves the given state to disk.
    static func save(
        products: Set<Product>,
        routines: [Routine],
        cycleProductColors: [UUID: Int],
        cycleProductOrder: [UUID],
        cycleAssignments: [String: Set<UUID>],
        cycleStartDate: Date?,
        cycleLength: Int,
        putOffRecords: [(productId: UUID, dayString: String, routineType: RoutineType)],
        reminderConfigs: [ReminderConfig]
    ) {
        let state = PersistedState(
            products: Array(products),
            routines: routines,
            cycleProductColors: Dictionary(uniqueKeysWithValues: cycleProductColors.map { ($0.key.uuidString, $0.value) }),
            cycleProductOrder: cycleProductOrder.map(\.uuidString),
            cycleAssignments: cycleAssignments.mapValues { Array($0).map(\.uuidString) },
            cycleStartDate: cycleStartDate,
            cycleLength: cycleLength,
            putOffRecords: putOffRecords.map { PutOffRecordCodable(productId: $0.productId, dayString: $0.dayString, routineType: $0.routineType) },
            reminderConfigs: reminderConfigs
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL)
    }
}
