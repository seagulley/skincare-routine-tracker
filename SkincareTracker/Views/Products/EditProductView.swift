//
//  EditProductView.swift
//  SkincareTracker
//

import SwiftUI

struct EditProductView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let product: Product
    
    @State private var name: String
    @State private var ingredientsText: String
    @State private var useFrequencyDays: Int
    @State private var useInMorning: Bool
    @State private var useInNight: Bool
    @State private var excludedProductIds: Set<UUID>
    
    private var otherProducts: [Product] {
        store.products.filter { $0.id != product.id }
    }
    
    init(product: Product) {
        self.product = product
        _name = State(initialValue: product.name)
        _ingredientsText = State(initialValue: product.ingredients.map(\.name).joined(separator: ", "))
        _useFrequencyDays = State(initialValue: product.frequencyDays)
        _useInMorning = State(initialValue: product.routineTypes.contains(.morning))
        _useInNight = State(initialValue: product.routineTypes.contains(.night))
        _excludedProductIds = State(initialValue: product.excludedProductIds)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    TextField("Product name", text: $name)
                }
                
                Section("Ingredients") {
                    TextField("Comma-separated ingredients", text: $ingredientsText, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Frequency") {
                    Stepper("Use every \(useFrequencyDays) day(s)", value: $useFrequencyDays, in: 1...30)
                }
                
                Section {
                    Toggle("Morning routine", isOn: $useInMorning)
                    Toggle("Night routine", isOn: $useInNight)
                } header: {
                    Text("Use in")
                } footer: {
                    Text("Choose which routines this product belongs to.")
                }
                
                if !otherProducts.isEmpty {
                    Section {
                        ForEach(otherProducts) { other in
                            Toggle(other.name, isOn: Binding(
                                get: { excludedProductIds.contains(other.id) },
                                set: { isOn in
                                    if isOn { excludedProductIds.insert(other.id) }
                                    else { excludedProductIds.remove(other.id) }
                                }
                            ))
                        }
                    } header: {
                        Text("Never use with")
                    } footer: {
                        Text("These products will be scheduled on different days so they never appear together.")
                    }
                }
            }
            .navigationTitle("Edit Product")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        let ingredients = ingredientsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 0 }
            .map { Ingredient(name: String($0)) }
        
        var routineTypes: Set<RoutineType> = []
        if useInMorning { routineTypes.insert(.morning) }
        if useInNight { routineTypes.insert(.night) }
        if routineTypes.isEmpty { routineTypes = [.morning, .night] }
        
        store.updateProduct(productId: product.id, name: name, ingredients: ingredients, frequencyDays: useFrequencyDays, routineTypes: routineTypes, excludedProductIds: excludedProductIds)
        dismiss()
    }
}
