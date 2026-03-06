//
//  EditRoutineView.swift
//  SkincareTracker
//

import SwiftUI

struct EditRoutineView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    
    let routineType: RoutineType
    @State private var selectedProductIds: [UUID] = []
    @State private var showAddProduct = false
    
    private var routine: Routine {
        routineType == .morning ? store.morningRoutine : store.nightRoutine
    }
    
    var body: some View {
        List {
            Section {
                ForEach(Array(selectedProductIds.enumerated()), id: \.element) { index, productId in
                    if let product = store.product(by: productId) {
                        HStack {
                            Text("\(index + 1).")
                                .foregroundStyle(.secondary)
                                .frame(width: 24, alignment: .leading)
                            Text(product.name)
                            Spacer()
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onMove(perform: moveProducts)
                .onDelete(perform: deleteProducts)
                
                Button {
                    showAddProduct = true
                } label: {
                    Label("Add Product", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Application Order")
            } footer: {
                Text("Drag to reorder. Products are applied in this order.")
            }
        }
        .navigationTitle(routineType == .morning ? "Morning Routine" : "Night Routine")
        .onAppear {
            selectedProductIds = routine.productIds
        }
        .onDisappear {
            store.updateRoutine(routineType, productIds: selectedProductIds)
        }
        .sheet(isPresented: $showAddProduct) {
            AddProductToRoutineView(
                routineType: routineType,
                currentIds: selectedProductIds,
                onAdd: { id in
                    selectedProductIds.append(id)
                }
            )
            .environmentObject(store)
        }
    }
    
    private func moveProducts(from source: IndexSet, to destination: Int) {
        selectedProductIds.move(fromOffsets: source, toOffset: destination)
    }
    
    private func deleteProducts(at offsets: IndexSet) {
        let idsToRemove = offsets.map { selectedProductIds[$0] }
        for productId in idsToRemove {
            guard var product = store.product(by: productId) else { continue }
            product.routineTypes.remove(routineType)
            store.updateProduct(product)
        }
        selectedProductIds.remove(atOffsets: offsets)
    }
}

struct AddProductToRoutineView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    
    let routineType: RoutineType
    let currentIds: [UUID]
    let onAdd: (UUID) -> Void
    
    private var availableProducts: [Product] {
        store.products.filter { product in
            product.routineTypes.contains(routineType) && !currentIds.contains(product.id)
        }
    }
    
    var body: some View {
        NavigationStack {
            List(availableProducts) { product in
                Button {
                    onAdd(product.id)
                    dismiss()
                } label: {
                    HStack {
                        Text(product.name)
                        Spacer()
                        Image(systemName: "plus")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if availableProducts.isEmpty {
                    ContentUnavailableView(
                        "No Products Available",
                        systemImage: "drop.fill",
                        description: Text(store.products.isEmpty
                            ? "Add skincare products first in the Products tab."
                            : "No products are configured for \(routineType.rawValue.lowercased()). Edit a product to enable it for this routine.")
                    )
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        EditRoutineView(routineType: .morning)
            .environmentObject(AppStore())
    }
}
