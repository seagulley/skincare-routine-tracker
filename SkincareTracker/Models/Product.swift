import Foundation

struct Product: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var ingredients: [Ingredient]
    var frequencyDays: Int  // Use every X days
    var lastUsedDate: Date?
    /// Which routines this product is used in: morning, night, or both
    var routineTypes: Set<RoutineType>
    /// Products that should never be used in the same routine (same day, same morning/night) as this one
    var excludedProductIds: Set<UUID>
    
    var frequencyDescription: String {
        frequencyDays == 1 ? "Daily" : "Every \(frequencyDays) days"
    }
    
    var routineDescription: String {
        if routineTypes.contains(.morning) && routineTypes.contains(.night) {
            return "Morning & Night"
        } else if routineTypes.contains(.morning) {
            return "Morning only"
        } else if routineTypes.contains(.night) {
            return "Night only"
        } else {
            return "Not in any routine"
        }
    }
    
    init(id: UUID = UUID(), name: String, ingredients: [Ingredient] = [], frequencyDays: Int = 1, lastUsedDate: Date? = nil, routineTypes: Set<RoutineType> = [.morning, .night], excludedProductIds: Set<UUID> = []) {
        self.id = id
        self.name = name
        self.ingredients = ingredients
        self.frequencyDays = frequencyDays
        self.lastUsedDate = lastUsedDate
        self.routineTypes = routineTypes
        self.excludedProductIds = excludedProductIds
    }
    
    /// Convenience init for ingredients as strings (e.g. from comma-separated input)
    init(id: UUID = UUID(), name: String, ingredientNames: [String], frequencyDays: Int = 1, lastUsedDate: Date? = nil, routineTypes: Set<RoutineType> = [.morning, .night], excludedProductIds: Set<UUID> = []) {
        self.id = id
        self.name = name
        self.ingredients = ingredientNames.map { Ingredient(name: $0) }
        self.frequencyDays = frequencyDays
        self.lastUsedDate = lastUsedDate
        self.routineTypes = routineTypes
        self.excludedProductIds = excludedProductIds
    }
}

struct Ingredient: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

extension Ingredient {
    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}
