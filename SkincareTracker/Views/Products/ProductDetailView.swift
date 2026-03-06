//
//  ProductDetailView.swift
//  SkincareTracker
//

import SwiftUI

struct ProductDetailView: View {
    @EnvironmentObject var store: AppStore
    let product: Product
    @State private var isEditing = false
    
    var body: some View {
        List {
            Section("Product") {
                Text(product.name)
                    .font(.headline)
            }
            
            Section("Ingredients") {
                if product.ingredients.isEmpty {
                    Text("No ingredients added")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(product.ingredients) { ingredient in
                        Text(ingredient.name)
                    }
                }
            }
            
            Section("Usage") {
                LabeledContent("Use every", value: "\(product.frequencyDays) day(s)")
                LabeledContent("Routines", value: product.routineDescription)
            }
        }
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    isEditing = true
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditProductView(product: product)
        }
    }
}

#Preview {
    NavigationStack {
        ProductDetailView(product: Product(name: "Vitamin C Serum", ingredientNames: ["Vitamin C", "Ferulic Acid"], frequencyDays: 1))
            .environmentObject(AppStore())
    }
}
