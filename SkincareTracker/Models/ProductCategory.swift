//
//  ProductCategory.swift
//  SkincareTracker
//
//  Skincare product categories in recommended application order.
//  Serum, Active, and Treatment share the same order; within that group, sort by product name.
//

import Foundation

/// A product category with a display name and application order.
struct ProductCategory: Identifiable, Hashable {
    let id: String
    let name: String
    /// Lower values = apply earlier. Serum/active/treatment share the same order.
    let applicationOrder: Int
    
    /// Default categories in recommended application order.
    /// toner > essence > exfoliant > lotion > serum = active = treatment > eye cream > lotion (emulsion) > cream > facial oil > SPF
    static let all: [ProductCategory] = [
        ProductCategory(id: "toner", name: "Toner", applicationOrder: 0),
        ProductCategory(id: "essence", name: "Essence", applicationOrder: 1),
        ProductCategory(id: "exfoliant", name: "Exfoliant", applicationOrder: 2),
        ProductCategory(id: "lotion", name: "Lotion", applicationOrder: 3),
        ProductCategory(id: "serum", name: "Serum", applicationOrder: 4),
        ProductCategory(id: "active", name: "Active", applicationOrder: 4),
        ProductCategory(id: "treatment", name: "Treatment", applicationOrder: 4),
        ProductCategory(id: "eye_cream", name: "Eye Cream", applicationOrder: 5),
        ProductCategory(id: "emulsion", name: "Emulsion", applicationOrder: 6),  // second lotion step
        ProductCategory(id: "cream", name: "Cream", applicationOrder: 7),
        ProductCategory(id: "facial_oil", name: "Facial Oil", applicationOrder: 8),
        ProductCategory(id: "spf", name: "SPF", applicationOrder: 9),
        ProductCategory(id: "other", name: "Other", applicationOrder: 99),
    ]
    
    /// Categories for picker display, ordered by application order.
    static var forPicker: [ProductCategory] {
        all.sorted { $0.applicationOrder < $1.applicationOrder }
    }
    
    static func category(id: String?) -> ProductCategory {
        guard let id else { return other }
        return all.first { $0.id == id } ?? other
    }
    
    static var other: ProductCategory {
        all.first { $0.id == "other" }!
    }
    
    /// Application order for the given category id. Nil/unknown = 99.
    static func applicationOrder(for categoryId: String?) -> Int {
        category(id: categoryId).applicationOrder
    }
    
    /// Whether this category shares its order with serum/active/treatment (alphabetical tie-break).
    static func usesAlphabeticalTieBreak(categoryId: String?) -> Bool {
        applicationOrder(for: categoryId) == 4
    }
}
