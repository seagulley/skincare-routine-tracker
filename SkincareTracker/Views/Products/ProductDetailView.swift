//
//  ProductDetailView.swift
//  SkincareTracker
//

import SwiftUI

struct ProductDetailView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var savedBanner: SavedBannerTrigger
    let product: Product
    @State private var isEditing = false
    
    var body: some View {
        List {
            Section("Product") {
                Text(product.name)
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                    .listRowBackground(AppColors.rowBackground)
                HStack {
                    Text("Category")
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Text(ProductCategory.category(id: product.categoryId).name)
                        .foregroundStyle(AppColors.textPrimary)
                }
                .listRowBackground(AppColors.rowBackground)
            }
            
            Section("Ingredients") {
                if product.ingredients.isEmpty {
                    Text("No ingredients added")
                        .foregroundStyle(AppColors.textSecondary)
                        .listRowBackground(AppColors.rowBackground)
                } else {
                    ForEach(product.ingredients) { ingredient in
                        Text(ingredient.name)
                            .foregroundStyle(AppColors.textPrimary)
                            .listRowBackground(AppColors.rowBackground)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
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
                .environmentObject(store)
                .environmentObject(savedBanner)
        }
    }
}

#Preview {
    NavigationStack {
        ProductDetailView(product: Product(name: "Vitamin C Serum", ingredientNames: ["Vitamin C", "Ferulic Acid"]))
            .environmentObject(AppStore())
            .environmentObject(SavedBannerTrigger())
    }
}
