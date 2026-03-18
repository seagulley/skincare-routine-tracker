import Foundation

/// Time and enabled state for a routine reminder (e.g. "Morning at 8:00" or "Night at 21:00").
/// One per routine type; used to schedule local notifications.
/// For morning, when useHealthWakeTime is true, reminder fires at Health wake time.
/// For night, when useHealthBedtime is true, reminder fires 1 hr before Health bedtime.
struct ReminderConfig: Identifiable, Codable {
    var id: UUID
    var routineType: RoutineType
    var hour: Int
    var minute: Int
    var isEnabled: Bool
    /// When true (morning only), uses Health wake time instead of hour/minute.
    var useHealthWakeTime: Bool
    /// When true (night only), uses Health bedtime minus 1 hour instead of hour/minute.
    var useHealthBedtime: Bool

    init(id: UUID = UUID(), routineType: RoutineType, hour: Int = 8, minute: Int = 0, isEnabled: Bool = true, useHealthWakeTime: Bool = false, useHealthBedtime: Bool = false) {
        self.id = id
        self.routineType = routineType
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
        self.useHealthWakeTime = useHealthWakeTime
        self.useHealthBedtime = useHealthBedtime
    }

    enum CodingKeys: String, CodingKey {
        case id, routineType, hour, minute, isEnabled, useHealthWakeTime, useHealthBedtime
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        routineType = try c.decode(RoutineType.self, forKey: .routineType)
        hour = try c.decode(Int.self, forKey: .hour)
        minute = try c.decode(Int.self, forKey: .minute)
        isEnabled = try c.decode(Bool.self, forKey: .isEnabled)
        useHealthWakeTime = try c.decodeIfPresent(Bool.self, forKey: .useHealthWakeTime) ?? false
        useHealthBedtime = try c.decodeIfPresent(Bool.self, forKey: .useHealthBedtime) ?? false
    }
}
