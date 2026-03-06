//
//  ProductsView.swift
//  SkincareTracker
//

import SwiftUI

struct ProductsView: View {
    @EnvironmentObject var store: AppStore
    @State private var showingAddProduct = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(store.products) { product in
                    NavigationLink(destination: ProductDetailView(product: product)) {
                        ProductRowView(product: product)
                    }
                }
                .onDelete(perform: store.deleteProducts)
            }
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
            }
        }
    }
}

struct ProductRowView: View {
    let product: Product
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(product.name)
                .font(.headline)
            HStack(spacing: 8) {
                if !product.ingredients.isEmpty {
                    Text("\(product.ingredients.count) ingredients")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("•")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(product.routineDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ProductsView()
        .environmentObject(AppStore())
}
