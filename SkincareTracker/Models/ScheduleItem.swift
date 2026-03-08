import Foundation

/// A single product occurrence in the schedule: one product on one date for one routine (morning/night).
/// Used to render the Today view, Schedule grid, and put-off logic. `shouldApply` reflects
/// whether the product is due that day based on frequency and exclusions.
struct ScheduleItem: Identifiable {
    var id: UUID
    var productId: UUID
    var productName: String
    var product: Product?
    var date: Date
    var routineType: RoutineType
    var order: Int
    var shouldApply: Bool
    var wasPutOff: Bool
    var appliedDate: Date?
    
    init(id: UUID = UUID(), productId: UUID, productName: String, product: Product? = nil, date: Date, routineType: RoutineType, order: Int, shouldApply: Bool, wasPutOff: Bool = false, appliedDate: Date? = nil) {
        self.id = id
        self.productId = productId
        self.productName = productName
        self.product = product
        self.date = date
        self.routineType = routineType
        self.order = order
        self.shouldApply = shouldApply
        self.wasPutOff = wasPutOff
        self.appliedDate = appliedDate
    }
}
