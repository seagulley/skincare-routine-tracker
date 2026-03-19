//
//  CycleView.swift
//  SkincareTracker
//
//  Lets users assign products to specific days and routines (morning/night) in a configurable cycle.
//

import SwiftUI


struct CycleView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var savedBanner: SavedBannerTrigger
    @State private var selectedProductId: UUID?
    @State private var showAddProduct = false
    @State private var expandedDayIndex: Int?
    @State private var productToRemove: Product?
    @State private var isProductsListEditing = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    cycleLengthSection
                    productsSection
                    dayGridSection
                    if !store.productsInCycle.isEmpty {
                        legendSection
                    }
                    if store.productsInCycle.isEmpty {
                        instructionsSection
                    }
                }
                .padding()
            }
            .background(AppColors.background)
            .navigationTitle("Skincare Cycle")
            .sheet(isPresented: $showAddProduct) {
                AddToCycleSheet(onProductAdded: { product in
                    selectedProductId = product.id
                })
                .environmentObject(store)
                .environmentObject(savedBanner)
            }
            .confirmationDialog("Remove from routine?", isPresented: Binding(
                get: { productToRemove != nil },
                set: { if !$0 { productToRemove = nil } }
            )) {
                Button("Remove", role: .destructive) {
                    if let product = productToRemove {
                        store.clearProductFromCycle(productId: product.id)
                        if selectedProductId == product.id {
                            selectedProductId = nil
                        }
                    }
                    productToRemove = nil
                }
                Button("Cancel", role: .cancel) {
                    productToRemove = nil
                }
            } message: {
                if let product = productToRemove {
                    Text("This will remove \"\(product.name)\" from your cycle.")
                }
            }
            .overlay(alignment: .bottom) {
                if store.hasUnsavedCycleChanges {
                    Button {
                        store.trySaveCycle(using: savedBanner)
                        selectedProductId = nil
                    } label: {
                        Text("Save")
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.textOnAccent)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(AppColors.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: store.hasUnsavedCycleChanges)
        }
    }
    
    private var cycleLengthSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cycle Length: \(store.cycleLength) days")
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)
            
            Slider(
                value: Binding(
                    get: { Double(store.cycleLength) },
                    set: { store.setCycleLength(Int($0.rounded())) }
                ),
                in: 2...14,
                step: 1
            )
            .tint(AppColors.accent)
            
            HStack {
                Text("2")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Text("14")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding()
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var productsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Products")
                    .font(.headline)
                Spacer()
                Button {
                    isProductsListEditing.toggle()
                    if isProductsListEditing {
                        selectedProductId = nil
                    }
                } label: {
                    Text(isProductsListEditing ? "Done" : "Reorder")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isProductsListEditing ? AppColors.textPrimary : AppColors.accent)
                }
                .buttonStyle(.bordered)
                .tint(isProductsListEditing ? AppColors.rowBackground : AppColors.accentLight)
                Button {
                    expandedDayIndex = nil
                    showAddProduct = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.textOnAccent)
                }
                .buttonStyle(.borderedProminent)
                .cornerRadius(24)
                .tint(AppColors.accent)
            }
            
            if store.productsInCycle.isEmpty {
                Text("No products in cycle. Tap Add to add from your collection or add a new product.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                List {
                    ForEach(store.productsInCycleOrdered) { product in
                        ProductRow(
                            product: product,
                            color: store.productColor(for: product),
                            isSelected: selectedProductId == product.id,
                            isReorderMode: isProductsListEditing,
                            onSelect: {
                                if !isProductsListEditing {
                                    selectedProductId = selectedProductId == product.id ? nil : product.id
                                }
                            },
                            onDelete: { productToRemove = product }
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppColors.surface)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    }
                    .onMove { store.moveProductInCycleOrder(from: $0, to: $1) }
                }
                .environment(\.editMode, .constant(isProductsListEditing ? .active : .inactive))
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .frame(minHeight: CGFloat(store.productsInCycleOrdered.count) * 52)
                .padding(.bottom, 8)
            }
            
            if selectedProductId != nil {
                Text("Click on days below to assign this product")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(AppColors.accentLight)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var dayGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Cycle Days")
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)
            
            VStack(spacing: 12) {
                ForEach(0..<store.cycleLength, id: \.self) { dayIndex in
                    let isToday = (store.currentCycleDayIndex ?? 0) == dayIndex
                    let morningProducts = store.productsSortedByCycleOrder(
                        store.productsOnCycleSlot(dayIndex: dayIndex, routineType: .morning).compactMap { store.product(by: $0) }
                    )
                    let nightProducts = store.productsSortedByCycleOrder(
                        store.productsOnCycleSlot(dayIndex: dayIndex, routineType: .night).compactMap { store.product(by: $0) }
                    )
                    
                    let isExpanded = expandedDayIndex == dayIndex
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Day \(dayIndex + 1)")
                                    .font(.headline)
                                    .foregroundStyle(AppColors.textPrimary)
                                if isToday {
                                    Text("Today")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(AppColors.textSecondary)
                                        .padding(.vertical, 2)
                                        .clipShape(Capsule())
                                }
                            }
                            .frame(minWidth: 72, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let productId = selectedProductId {
                                    store.toggleProductOnCycleSlot(productId: productId, dayIndex: dayIndex, routineType: .morning)
                                } else {
                                    expandedDayIndex = expandedDayIndex == dayIndex ? nil : dayIndex
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                CycleSlotCell(
                                    dayIndex: dayIndex,
                                    routineType: .morning,
                                    productIds: store.productsOnCycleSlot(dayIndex: dayIndex, routineType: .morning),
                                    products: morningProducts,
                                    store: store,
                                    selectedProductId: selectedProductId,
                                    isDayExpanded: isExpanded,
                                    productColor: { store.productColor(for: $0) }
                                )
                                if isExpanded {
                                    routineDetailPanel(products: morningProducts, routineType: .morning)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let productId = selectedProductId {
                                    store.toggleProductOnCycleSlot(productId: productId, dayIndex: dayIndex, routineType: .morning)
                                } else {
                                    expandedDayIndex = expandedDayIndex == dayIndex ? nil : dayIndex
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                CycleSlotCell(
                                    dayIndex: dayIndex,
                                    routineType: .night,
                                    productIds: store.productsOnCycleSlot(dayIndex: dayIndex, routineType: .night),
                                    products: nightProducts,
                                    store: store,
                                    selectedProductId: selectedProductId,
                                    isDayExpanded: isExpanded,
                                    productColor: { store.productColor(for: $0) }
                                )
                                if isExpanded {
                                    routineDetailPanel(products: nightProducts, routineType: .night)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let productId = selectedProductId {
                                    store.toggleProductOnCycleSlot(productId: productId, dayIndex: dayIndex, routineType: .night)
                                } else {
                                    expandedDayIndex = expandedDayIndex == dayIndex ? nil : dayIndex
                                }
                            }
                        }
                        .padding(isToday ? 8 : 0)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isToday ? AppColors.accent : Color.clear, lineWidth: 2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .contextMenu {
                            Button("Set as today") {
                                store.setTodayToCycleDay(dayIndex)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var legendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Legend:")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(store.productsInCycleOrdered) { product in
                    HStack(spacing: 6) {
                        if let color = store.productColor(for: product) {
                            Circle()
                                .fill(color)
                                .frame(width: 12, height: 12)
                        }
                        Text(product.name)
                            .font(.caption)
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }
            }
        }
        .padding()
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How to use:")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.primaryAction)
            
            VStack(alignment: .leading, spacing: 4) {
                instructionRow(1, "Add products to the cycle (new product or from collection)")
                instructionRow(2, "Tap Reorder to drag products and set application order")
                instructionRow(3, "Tap a product to select it, then tap morning/night cells to assign")
            }
            .font(.caption)
            .foregroundStyle(AppColors.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.primaryActionLight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func instructionRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(number).")
            Text(text)
        }
    }
    
    @ViewBuilder
    private func routineDetailPanel(products: [Product], routineType: RoutineType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if products.isEmpty {
                Text("No products assigned")
                    .font(.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(products) { product in
                        HStack(spacing: 8) {
                            if let color = store.productColor(for: product) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 8, height: 8)
                            }
                            Text(product.name)
                                .font(.caption)
                                .foregroundStyle(AppColors.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
        }
        .background(AppColors.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
}

// MARK: - Product Row

private struct ProductRow: View {
    let product: Product
    let color: Color?
    let isSelected: Bool
    var isReorderMode: Bool = false
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                if isReorderMode {
                    Image(systemName: "line.3.horizontal")
                        .font(.body)
                        .foregroundStyle(AppColors.textSecondary)
                }
                
                if let color {
                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.textPrimary)
                }
                
                Spacer()
                
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(isSelected ? AppColors.rowSelected : AppColors.rowBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected && !isReorderMode ? AppColors.accent : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cycle Slot Cell

private struct CycleSlotCell: View {
    let dayIndex: Int
    let routineType: RoutineType
    let productIds: Set<UUID>
    let products: [Product]
    let store: AppStore
    let selectedProductId: UUID?
    let isDayExpanded: Bool
    let productColor: (Product) -> Color?
    
    private var isSelected: Bool {
        guard let id = selectedProductId else { return false }
        return productIds.contains(id)
    }
    
    private var emptyBackground: Color {
        routineType == .morning ? AppColors.morningCellEmpty : AppColors.nightCellEmpty
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: routineType == .morning ? "sun.max.fill" : "moon.fill")
                .font(.caption)
                .foregroundStyle(routineType == .morning ? AppColors.morningAccent : AppColors.nightAccent)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 12)

            Text(routineType == .morning ? "Morning" : "Night")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.textSecondary)
            
            if products.isEmpty {
                Text("Tap to add")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textTertiary)
            } else {
                Text("\(products.count) \(products.count == 1 ? "product" : "products")")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .background(emptyBackground)
        .overlay(alignment: .bottom) {
            if !products.isEmpty {
                HStack(spacing: 4) {
                    ForEach(products.prefix(5)) { product in
                        if let color = productColor(product) {
                            Circle()
                                .fill(color)
                                .frame(width: 6, height: 6)
                        }
                    }
                    if products.count > 5 {
                        Text("...")
                            .font(.caption2)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
                .padding(.bottom, 6)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? AppColors.accent : (isDayExpanded ? (routineType == .morning ? AppColors.morningAccent : AppColors.nightAccent) : Color.clear), lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    CycleView()
        .environmentObject(AppStore())
}
