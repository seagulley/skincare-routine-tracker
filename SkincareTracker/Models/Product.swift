import Foundation

/// A skincare product the user owns and uses in their routine.
/// Stores name, ingredients, and category. Usage is configured in the Cycle editor.
struct Product: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var ingredients: [Ingredient]
    /// Product category for recommended application order. Nil = Other.
    var categoryId: String?
    
    init(id: UUID = UUID(), name: String, ingredients: [Ingredient] = [], categoryId: String? = nil) {
        self.id = id
        self.name = name
        self.ingredients = ingredients
        self.categoryId = categoryId
    }
    
    /// Convenience init for ingredients as strings (e.g. from comma-separated input)
    init(id: UUID = UUID(), name: String, ingredientNames: [String], categoryId: String? = nil) {
        self.id = id
        self.name = name
        self.ingredients = ingredientNames.map { Ingredient(name: $0) }
        self.categoryId = categoryId
    }
}

/// A single ingredient within a product (e.g. "Vitamin C", "Niacinamide").
/// Used for display and to support future features like ingredient overlap warnings.
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
