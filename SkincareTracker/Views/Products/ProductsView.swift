//
//  ProductsView.swift
//  SkincareTracker
//

import SwiftUI

struct ProductsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var savedBanner: SavedBannerTrigger
    @State private var showingAddProduct = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(store.sortedProducts) { product in
                    NavigationLink(destination: ProductDetailView(product: product)) {
                        ProductRowView(product: product)
                    }
                    .listRowBackground(AppColors.rowBackground)
                }
                .onDelete { offsets in
                    store.deleteProducts(at: offsets, from: store.sortedProducts)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("Products")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddProduct = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAddProduct) {
                AddProductView()
                    .environmentObject(store)
                    .environmentObject(savedBanner)
            }
        }
    }
}

struct ProductRowView: View {
    @EnvironmentObject var store: AppStore
    let product: Product
    
    private var isInCycle: Bool {
        store.productsInCycle.contains(where: { $0.id == product.id })
    }
    
    var body: some View {
        HStack(spacing: 10) {
            if isInCycle, let color = store.productColor(for: product) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                if !product.ingredients.isEmpty {
                    Text("\(product.ingredients.count) ingredients")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ProductsView()
        .environmentObject(AppStore())
        .environmentObject(SavedBannerTrigger())
}
