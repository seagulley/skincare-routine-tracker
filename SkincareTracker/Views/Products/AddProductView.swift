//
//  AddProductView.swift
//  SkincareTracker
//

import SwiftUI

struct AddProductView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var ingredientsText = ""
    @State private var frequencyDays = 1
    @State private var morning = true
    @State private var night = true
    @State private var excludedProductIds: Set<UUID> = []
    
    private var otherProducts: [Product] {
        store.products
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    TextField("Product name", text: $name)
                }
                
                Section("Ingredients") {
                    TextField("Comma-separated ingredients (e.g. Niacinamide, Hyaluronic Acid)", text: $ingredientsText, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Frequency") {
                    Stepper("Use every \(frequencyDays) day(s)", value: $frequencyDays, in: 1...30)
                }
                
                Section {
                    Toggle("Morning routine", isOn: $morning)
                    Toggle("Night routine", isOn: $night)
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
            .navigationTitle("Add Product")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProduct()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveProduct() {
        let ingredientNames = ingredientsText
            .split(separator: ",")
            .compactMap { part -> String? in
                let trimmed = part.trimmingCharacters(in: .whitespaces)
                return trimmed.isEmpty ? nil : String(trimmed)
            }
        
        var routineTypes: Set<RoutineType> = []
        if morning { routineTypes.insert(.morning) }
        if night { routineTypes.insert(.night) }
        if routineTypes.isEmpty { routineTypes = [.morning, .night] }
        
        let product = Product(
            name: name,
            ingredientNames: ingredientNames,
            frequencyDays: frequencyDays,
            routineTypes: routineTypes,
            excludedProductIds: excludedProductIds
        )
        store.addProduct(product)
        dismiss()
    }
}

#Preview {
    AddProductView()
        .environmentObject(AppStore())
}
