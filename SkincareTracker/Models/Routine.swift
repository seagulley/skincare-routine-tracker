import Foundation

/// Distinguishes the morning routine from the night routine.
enum RoutineType: String, Codable, CaseIterable {
    case morning = "Morning"
    case night = "Night"
}

/// A morning or night routine: an ordered list of product IDs.
/// The order determines application sequence (e.g. cleanser before serum).
struct Routine: Identifiable, Codable {
    var id: UUID
    var type: RoutineType
    var productIds: [UUID]  // Order of application
    var lastUpdated: Date
    
    init(id: UUID = UUID(), type: RoutineType, productIds: [UUID] = []) {
        self.id = id
        self.type = type
        self.productIds = productIds
        self.lastUpdated = Date()
    }
}
