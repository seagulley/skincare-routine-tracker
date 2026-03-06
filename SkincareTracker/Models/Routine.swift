import Foundation

enum RoutineType: String, Codable, CaseIterable {
    case morning = "Morning"
    case night = "Night"
}

struct Routine: Identifiable, Codable {
    var id: UUID
    var type: RoutineType
    var productIds: [UUID]  // Order of application
    
    init(id: UUID = UUID(), type: RoutineType, productIds: [UUID] = []) {
        self.id = id
        self.type = type
        self.productIds = productIds
    }
}
