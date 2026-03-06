import Foundation

struct ReminderConfig: Identifiable, Codable {
    var id: UUID
    var routineType: RoutineType
    var hour: Int
    var minute: Int
    var isEnabled: Bool
    
    init(id: UUID = UUID(), routineType: RoutineType, hour: Int = 8, minute: Int = 0, isEnabled: Bool = true) {
        self.id = id
        self.routineType = routineType
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
    }
}
