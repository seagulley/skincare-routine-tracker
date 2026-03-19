//
//  AppStore.swift
//  SkincareTracker
//
//  Central app state for skincare data
//

import Foundation
import SwiftUI

/// Records that a product was put off for a specific date and routine.
private struct PutOffRecord: Hashable {
    let productId: UUID
    let dayString: String
    let routineType: RoutineType
}

@MainActor
final class AppStore: ObservableObject {
    @Published var products: Set<Product> = []
    /// Maps product ID to palette index. Assigned when product is placed in a routine (day slot); cleared when removed from cycle.
    @Published var cycleProductColors: [UUID: Int] = [:]
    /// Ordered list of product IDs in the cycle; defines routine application order. Categories provide default; user can refine via drag.
    @Published var cycleProductOrder: [UUID] = []

    /// Returns all products as an array, sorted by name for predictable display.
    var sortedProducts: [Product] {
        products.sorted { $0.name < $1.name }
    }

    /// Products for the Products tab: cycle products first (in cycle order), then rest alphabetically.
    var productsForListView: [Product] {
        productsInCycleOrdered + productsNotInCycle
    }

    /// Products that have been added to the cycle. Sorted by name.
    var productsInCycle: [Product] {
        products.filter { cycleProductOrder.contains($0.id) }.sorted { $0.name < $1.name }
    }

    /// Products in cycle ordered by cycleProductOrder (user's drag order).
    var productsInCycleOrdered: [Product] {
        cycleProductOrder.compactMap { product(by: $0) }
    }

    /// Products not yet in the cycle. Sorted by name.
    var productsNotInCycle: [Product] {
        products.filter { !cycleProductOrder.contains($0.id) }.sorted { $0.name < $1.name }
    }

    /// Finds a product by its id.
    /// - Parameter id: The product's UUID.
    /// - Returns: The product if found, otherwise nil.
    func product(by id: UUID) -> Product? {
        products.first(where: { $0.id == id })
    }
    @Published var routines: [Routine] = []
    @Published var scheduleItems: [ScheduleItem] = []
    /// Tracks (productId, date, routineType) put-offs so the product is hidden that day only.
    private var putOffRecords: Set<PutOffRecord> = []
    @Published var reminderConfigs: [ReminderConfig] = [
        ReminderConfig(routineType: .morning, hour: 8, minute: 0),
        ReminderConfig(routineType: .night, hour: 21, minute: 0)
    ]

    /// Cycle length (2-14 days) for the Cycle tab.
    @Published var cycleLength: Int = 7
    
    /// Maps "dayIndex-routineType" (e.g. "1-Morning") to product IDs assigned to that slot.
    @Published var cycleAssignments: [String: Set<UUID>] = [:]
    
    /// Reference date for the cycle: day 0. Set when user saves the cycle.
    @Published var cycleStartDate: Date?
    /// True when cycle assignments, length, or today have changed since last save.
    @Published var hasUnsavedCycleChanges: Bool = false
    
    /// The 0-based cycle day index for today, or nil if the cycle has not been saved.
    var currentCycleDayIndex: Int? {
        guard let refDate = cycleStartDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let refStart = calendar.startOfDay(for: refDate)
        let daysSince = calendar.dateComponents([.day], from: refStart, to: today).day ?? 0
        return ((daysSince % cycleLength) + cycleLength) % cycleLength
    }
    
    // MARK: - Computed
    
    /// The morning routine, or an empty placeholder if none exists.
    var morningRoutine: Routine {
        routine(for: .morning) ?? Routine(type: .morning)
    }
    
    /// The night routine, or an empty placeholder if none exists.
    var nightRoutine: Routine {
        routine(for: .night) ?? Routine(type: .night)
    }
    
    /// Schedule items for today's morning routine, filtered to those that should apply and sorted by order.
    var todayMorningItems: [ScheduleItem] {
        todayItems(for: .morning)
    }
    
    /// Schedule items for today's night routine, filtered to those that should apply and sorted by order.
    var todayNightItems: [ScheduleItem] {
        todayItems(for: .night)
    }
    
    /// Returns schedule items for today and the given routine type.
    /// - Parameter type: Morning or night routine.
    /// - Returns: Items for today matching the routine type, filtered to shouldApply, sorted by order.
    private func todayItems(for type: RoutineType) -> [ScheduleItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return scheduleItems.filter { item in
            calendar.isDate(item.date, inSameDayAs: today) && item.routineType == type && item.shouldApply
        }.sorted { $0.order < $1.order }
    }
    
    // MARK: - Products
    
    /// Returns true if a product with the same name and category already exists.
    /// - Parameters:
    ///   - name: Product name (compared case-insensitively).
    ///   - categoryId: Category id; nil is treated as "other".
    ///   - excludingProductId: If set, this product is excluded (for edits).
    func hasDuplicateProduct(name: String, categoryId: String?, excludingProductId: UUID? = nil) -> Bool {
        let normalizedName = name.trimmingCharacters(in: .whitespaces).lowercased()
        let catId = categoryId ?? "other"
        guard !normalizedName.isEmpty else { return false }
        return products.contains { p in
            p.id != excludingProductId &&
            p.name.lowercased() == normalizedName &&
            (p.categoryId ?? "other") == catId
        }
    }
    
    /// Adds a product and rebuilds the schedule.
    /// - Parameter product: The product to add.
    func addProduct(_ product: Product) {
        products.insert(product)
        rebuildSchedule(from: Date())
    }
    
    /// Replaces an existing product with the same id, then rebuilds the schedule.
    /// - Parameter product: The updated product (must have an id of an existing product).
    func updateProduct(_ product: Product) {
        if let existing = products.first(where: { $0.id == product.id }) {
            products.remove(existing)
            products.insert(product)
        }
        rebuildSchedule(from: Date())
    }
    
    /// Updates specific fields of a product by id. Only non-nil parameters are applied.
    func updateProduct(productId: UUID, name: String? = nil, ingredients: [Ingredient]? = nil, categoryId: String? = nil) {
        guard var product = product(by: productId) else { return }
        if let n = name { product.name = n }
        if let i = ingredients { product.ingredients = i }
        if categoryId != nil {
            product.categoryId = categoryId
        }
        updateProduct(product)
    }
    
    /// Removes a product from the store and routines, then rebuilds the schedule.
    /// - Parameter product: The product to remove.
    func removeProduct(_ product: Product) {
        if let existing = products.first(where: { $0.id == product.id }) {
            products.remove(existing)
        }
        clearProductFromCycle(productId: product.id)
        putOffRecords = putOffRecords.filter { $0.productId != product.id }
        routines = routines.map { routine in
            var r = routine
            r.productIds = r.productIds.filter { $0 != product.id }
            return r
        }
        rebuildSchedule(from: Date())
    }
    
    /// Deletes products at the given indices from an ordered list (e.g. sortedProducts).
    /// - Parameters:
    ///   - offsets: Indices to delete.
    ///   - orderedProducts: The ordered array (e.g. sortedProducts).
    func deleteProducts(at offsets: IndexSet, from orderedProducts: [Product]) {
        for index in offsets {
            removeProduct(orderedProducts[index])
        }
    }

    // MARK: - Cycle Product Colors

    /// Returns the color for a product. Uses cycle-assigned color if product is in cycle; otherwise gray.
    /// Returns the product's cycle color, or nil if none assigned.
    func productColor(for product: Product) -> Color? {
        guard let idx = cycleProductColors[product.id] else { return nil }
        let safeIdx = max(0, min(idx, AppColors.productPalette.count - 1))
        return AppColors.productPalette[safeIdx]
    }

    /// Sorts products by cycleProductOrder when available, then by category. Products not in cycleProductOrder are appended in category order.
    func productsSortedByCycleOrder(_ products: [Product]) -> [Product] {
        guard !cycleProductOrder.isEmpty else {
            return productsSortedByCategoryOnly(products)
        }
        let productIds = Set(products.map(\.id))
        let ordered: [Product] = cycleProductOrder.compactMap { id -> Product? in
            guard productIds.contains(id), let p = product(by: id) else { return nil }
            return p
        }
        let notInOrder = products.filter { !cycleProductOrder.contains($0.id) }
        return ordered + productsSortedByCategoryOnly(notInOrder)
    }

    /// Sorts products by category application order only (used when cycleProductOrder is empty or for products not in it).
    private func productsSortedByCategoryOnly(_ products: [Product]) -> [Product] {
        products.sorted { a, b in
            let orderA = ProductCategory.applicationOrder(for: a.categoryId)
            let orderB = ProductCategory.applicationOrder(for: b.categoryId)
            if orderA != orderB { return orderA < orderB }
            if ProductCategory.usesAlphabeticalTieBreak(categoryId: a.categoryId) {
                return a.name.localizedCompare(b.name) == .orderedAscending
            }
            return (cycleProductColors[a.id] ?? Int.max) < (cycleProductColors[b.id] ?? Int.max)
        }
    }

    /// Adds a product to the cycle. Inserts at category-appropriate position. Color is assigned only when the product is placed in a routine (day slot).
    func addProductToCycle(_ product: Product) {
        guard products.contains(product) else { return }
        guard !cycleProductOrder.contains(product.id) else { return }

        let productOrder = ProductCategory.applicationOrder(for: product.categoryId)
        var insertIndex = cycleProductOrder.count
        for (i, id) in cycleProductOrder.enumerated() {
            guard let p = self.product(by: id) else { continue }
            if ProductCategory.applicationOrder(for: p.categoryId) > productOrder {
                insertIndex = i
                break
            }
        }
        cycleProductOrder.insert(product.id, at: insertIndex)
        // Don't assign color here: color is given only when product is added to a routine (assignProductToCycleSlot).
        // Don't set hasUnsavedCycleChanges: adding without assigning to a day slot doesn't affect the schedule.
    }

    /// Removes a product from cycle and clears its assigned color.
    private func removeProductColor(productId: UUID) {
        cycleProductColors.removeValue(forKey: productId)
        cycleProductOrder.removeAll { $0 == productId }
    }

    /// Orders product IDs by cycleProductOrder; IDs not in order are appended in category order.
    private func orderProductIdsByCycleOrder(_ ids: [UUID]) -> [UUID] {
        let products = ids.compactMap { product(by: $0) }
        return productsSortedByCycleOrder(products).map(\.id)
    }

    /// Moves products in cycleProductOrder (for drag reorder). Called from List.onMove.
    /// Uses display indices (productsInCycleOrdered) so List reordering works correctly, including to last row.
    func moveProductInCycleOrder(from source: IndexSet, to destination: Int) {
        var ordered = productsInCycleOrdered
        guard !ordered.isEmpty else { return }
        ordered.move(fromOffsets: source, toOffset: destination)
        cycleProductOrder = ordered.map(\.id)
        if !cycleAssignments.isEmpty { hasUnsavedCycleChanges = true }
    }

    // MARK: - Routines
    
    /// Adds a routine and rebuilds the schedule.
    /// - Parameter routine: The routine to add.
    func addRoutine(_ routine: Routine) {
        routines.append(routine)
    }
    
    /// Updates or adds a routine by id, then rebuilds the schedule.
    /// - Parameter routine: The routine to update (matched by id).
    func updateRoutine(_ routine: Routine) {
        if let idx = routines.firstIndex(where: { $0.id == routine.id }) {
            routines[idx] = routine
        } else {
            routines.append(routine)
        }
        rebuildSchedule(from: Date())
    }
    
    /// Replaces a routine's product order and rebuilds the schedule.
    /// - Parameters:
    ///   - type: Morning or night routine.
    ///   - productIds: New ordered list of product ids for the routine.
    func updateRoutine(_ type: RoutineType, productIds: [UUID]) {
        var routine = routine(for: type) ?? Routine(type: type)
        routine.productIds = productIds
        updateRoutine(routine)
        rebuildSchedule(from: Date())
    }
    
    /// Returns the routine for the given type.
    /// - Parameter type: Morning or night.
    /// - Returns: The routine if it exists, otherwise nil.
    func routine(for type: RoutineType) -> Routine? {
        routines.first { $0.type == type }
    }
    
    // MARK: - Schedule / Put Off
    
    /// Puts off a product for today only.
    /// - Parameters:
    ///   - item: The schedule item to put off.
    ///   - routineType: The routine (morning/night).
    func putOff(_ item: ScheduleItem, routineType: RoutineType) {
        guard product(by: item.productId) != nil else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayString = dayString(from: today)
        putOffRecords.insert(PutOffRecord(productId: item.productId, dayString: dayString, routineType: routineType))
        rebuildSchedule(from: Date())
    }

    /// Converts a date to "YYYY-M-D" for put-off record keys.
    /// - Parameter date: The date to format.
    /// - Returns: A string like "2025-3-15".
    private func dayString(from date: Date) -> String {
        let calendar = Calendar.current
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(c.year!)-\(c.month!)-\(c.day!)"
    }

    /// Returns whether a product was put off for the given date and routine.
    /// - Parameters:
    ///   - productId: The product.
    ///   - date: The date.
    ///   - routineType: The routine.
    /// - Returns: True if the product was put off for that date/routine.
    private func isPutOff(productId: UUID, date: Date, routineType: RoutineType) -> Bool {
        let calendar = Calendar.current
        let dayString = self.dayString(from: calendar.startOfDay(for: date))
        return putOffRecords.contains(PutOffRecord(productId: productId, dayString: dayString, routineType: routineType))
    }

    /// Regenerates the schedule from the given start date (14 days ahead).
    /// - Parameter date: The start date (typically today).
    func rebuildSchedule(from date: Date) {
        scheduleItems = generateSchedule(from: date, daysAhead: 14)
    }
    
    /// Generates schedule items for each date and routine from cycle assignments.
    func generateSchedule(from startDate: Date, daysAhead: Int) -> [ScheduleItem] {
        guard !cycleAssignments.isEmpty, let refDate = cycleStartDate else { return [] }
        return generateScheduleFromCycle(startDate: startDate, daysAhead: daysAhead, refDate: refDate)
    }
    
    /// Schedule from cycle assignments: each date maps to a cycle day, products come from cycle slots.
    private func generateScheduleFromCycle(startDate: Date, daysAhead: Int, refDate: Date) -> [ScheduleItem] {
        var items: [ScheduleItem] = []
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        let refStart = calendar.startOfDay(for: refDate)
        
        for dayOffset in 0..<daysAhead {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay) else { continue }
            let daysSince = calendar.dateComponents([.day], from: refStart, to: date).day ?? 0
            let cycleDay = ((daysSince % cycleLength) + cycleLength) % cycleLength
            
            for routineType in RoutineType.allCases {
                let productIds = productsOnCycleSlot(dayIndex: cycleDay, routineType: routineType)
                let products = productIds.compactMap { product(by: $0) }
                let orderedIds = productsSortedByCycleOrder(products).map(\.id)
                for (order, productId) in orderedIds.enumerated() {
                    guard let product = product(by: productId) else { continue }
                    let shouldApply = !isPutOff(productId: productId, date: date, routineType: routineType)
                    items.append(ScheduleItem(
                        productId: productId,
                        productName: product.name,
                        product: product,
                        date: date,
                        routineType: routineType,
                        order: order,
                        shouldApply: shouldApply,
                        wasPutOff: false
                    ))
                }
            }
        }
        return items
    }
    
    init() {
        rebuildSchedule(from: Date())
    }
    
    // MARK: - Cycle
    
    private func cycleSlotKey(dayIndex: Int, routineType: RoutineType) -> String {
        "\(dayIndex)-\(routineType.rawValue)"
    }
    
    private static let maxProductsPerSlot = 20

    /// Assigns a product to a day+routine slot. Adds to cycle if needed; assigns color when placing in a routine. Max 20 products per slot.
    func assignProductToCycleSlot(productId: UUID, dayIndex: Int, routineType: RoutineType) {
        guard dayIndex >= 0, dayIndex < cycleLength else { return }
        guard product(by: productId) != nil else { return }
        let key = cycleSlotKey(dayIndex: dayIndex, routineType: routineType)
        let current = cycleAssignments[key] ?? []
        guard !current.contains(productId), current.count < Self.maxProductsPerSlot else { return }
        if !cycleProductOrder.contains(productId), let p = product(by: productId) {
            addProductToCycle(p)
        }
        if cycleProductColors[productId] == nil {
            let nextIndex = cycleProductColors.values.max().map { $0 + 1 } ?? 0
            cycleProductColors[productId] = nextIndex % AppColors.productPalette.count
        }
        var assignments = current
        assignments.insert(productId)
        cycleAssignments[key] = assignments
        hasUnsavedCycleChanges = true
    }
    
    /// Removes a product from a day+routine slot.
    func unassignProductFromCycleSlot(productId: UUID, dayIndex: Int, routineType: RoutineType) {
        let key = cycleSlotKey(dayIndex: dayIndex, routineType: routineType)
        var assignments = cycleAssignments[key] ?? []
        assignments.remove(productId)
        if assignments.isEmpty {
            cycleAssignments.removeValue(forKey: key)
        } else {
            cycleAssignments[key] = assignments
        }
        hasUnsavedCycleChanges = true
    }
    
    /// Toggles product assignment for a day+routine slot.
    func toggleProductOnCycleSlot(productId: UUID, dayIndex: Int, routineType: RoutineType) {
        guard product(by: productId) != nil else { return }
        let key = cycleSlotKey(dayIndex: dayIndex, routineType: routineType)
        let assigned = (cycleAssignments[key] ?? []).contains(productId)
        if assigned {
            unassignProductFromCycleSlot(productId: productId, dayIndex: dayIndex, routineType: routineType)
        } else {
            assignProductToCycleSlot(productId: productId, dayIndex: dayIndex, routineType: routineType)
        }
    }
    
    /// Returns product IDs assigned to the given day and routine slot.
    func productsOnCycleSlot(dayIndex: Int, routineType: RoutineType) -> Set<UUID> {
        cycleAssignments[cycleSlotKey(dayIndex: dayIndex, routineType: routineType)] ?? []
    }

    /// Removes a product from all cycle slots and clears its assigned color. Does not delete the product from the collection.
    func clearProductFromCycle(productId: UUID) {
        for dayIndex in 0..<cycleLength {
            for routineType in RoutineType.allCases {
                unassignProductFromCycleSlot(productId: productId, dayIndex: dayIndex, routineType: routineType)
            }
        }
        removeProductColor(productId: productId)
        hasUnsavedCycleChanges = true
    }

    /// Returns the 0-based cycle day index for a given date. Uses cycleStartDate when available; otherwise returns 0.
    func cycleDayIndex(for date: Date) -> Int {
        guard let refDate = cycleStartDate else { return 0 }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let refStart = calendar.startOfDay(for: refDate)
        let daysSince = calendar.dateComponents([.day], from: refStart, to: dayStart).day ?? 0
        return ((daysSince % cycleLength) + cycleLength) % cycleLength
    }

    /// Products assigned to a given date's cycle day for a routine type, sorted by category application order.
    func productsForDate(_ date: Date, routineType: RoutineType) -> [Product] {
        let dayIndex = cycleDayIndex(for: date)
        let products = productsOnCycleSlot(dayIndex: dayIndex, routineType: routineType)
            .compactMap { product(by: $0) }
        return productsSortedByCycleOrder(products)
    }

    /// Updates cycle length and prunes assignments for days that no longer exist.
    func setCycleLength(_ length: Int) {
        let clamped = max(2, min(14, length))
        cycleLength = clamped
        cycleAssignments = cycleAssignments.filter { entry in
            guard let dayPart = entry.key.split(separator: "-").first, let day = Int(dayPart) else { return true }
            return day < clamped
        }
        hasUnsavedCycleChanges = true
    }
    
    /// Applies cycle assignments to routines: builds product lists from cycle slots in cycleProductOrder, updates routines.
    func applyCycleToRoutines() {
        var morningProductIds = Set<UUID>()
        var nightProductIds = Set<UUID>()
        
        for dayIndex in 0..<cycleLength {
            for id in productsOnCycleSlot(dayIndex: dayIndex, routineType: .morning) {
                morningProductIds.insert(id)
            }
            for id in productsOnCycleSlot(dayIndex: dayIndex, routineType: .night) {
                nightProductIds.insert(id)
            }
        }

        let morningIds = orderProductIdsByCycleOrder(Array(morningProductIds))
        let nightIds = orderProductIdsByCycleOrder(Array(nightProductIds))
        
        updateRoutine(.morning, productIds: morningIds)
        updateRoutine(.night, productIds: nightIds)
    }
    
    /// Saves the cycle: applies cycle to routines and rebuilds the schedule.
    /// Preserves which day is "today" if already set via "Set as today"; otherwise defaults to Day 1.
    func saveCycle() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if cycleStartDate == nil {
            cycleStartDate = today
        }
        applyCycleToRoutines()
        rebuildSchedule(from: today)
        hasUnsavedCycleChanges = false
    }

    /// Attempts to save the cycle. If the cycle is empty, shows the "Cycle is empty" banner instead of saving.
    func trySaveCycle(using savedBanner: SavedBannerTrigger) {
        if cycleAssignments.isEmpty {
            savedBanner.show("Cycle is empty", success: false)
        } else {
            saveCycle()
            savedBanner.show()
        }
    }

    /// Sets the cycle so the given day index is "today". When no cycle is saved, Day 1 is today by default.
    /// Call this when the user drags the Today badge to a different day.
    func setTodayToCycleDay(_ dayIndex: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let refStart = calendar.date(byAdding: .day, value: -dayIndex, to: today) else { return }
        cycleStartDate = refStart
        rebuildSchedule(from: today)
        hasUnsavedCycleChanges = true
    }
    
    // MARK: - Reminders
    
    /// Returns the reminder config for a routine type.
    /// - Parameter type: Morning or night.
    /// - Returns: The config if it exists, otherwise a default (no reminder).
    func reminderConfig(for type: RoutineType) -> ReminderConfig {
        reminderConfigs.first { $0.routineType == type } ?? ReminderConfig(routineType: type)
    }
    
    /// Updates or adds a reminder config.
    /// - Parameter config: The reminder config (hour, minute for morning/night).
    func updateReminderConfig(_ config: ReminderConfig) {
        if let idx = reminderConfigs.firstIndex(where: { $0.routineType == config.routineType }) {
            reminderConfigs[idx] = config
        } else {
            reminderConfigs.append(config)
        }
    }
}
