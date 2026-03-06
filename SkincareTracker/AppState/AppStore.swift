//
//  AppStore.swift
//  SkincareTracker
//
//  Central app state for skincare data
//

import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var products: [Product] = []
    @Published var routines: [Routine] = []
    @Published var scheduleItems: [ScheduleItem] = []
    @Published var reminderConfigs: [ReminderConfig] = [
        ReminderConfig(routineType: .morning, hour: 8, minute: 0),
        ReminderConfig(routineType: .night, hour: 21, minute: 0)
    ]
    
    // MARK: - Computed
    
    var morningRoutine: Routine {
        routine(for: .morning) ?? Routine(type: .morning)
    }
    
    var nightRoutine: Routine {
        routine(for: .night) ?? Routine(type: .night)
    }
    
    var todayMorningItems: [ScheduleItem] {
        todayItems(for: .morning)
    }
    
    var todayNightItems: [ScheduleItem] {
        todayItems(for: .night)
    }
    
    private func todayItems(for type: RoutineType) -> [ScheduleItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return scheduleItems.filter { item in
            calendar.isDate(item.date, inSameDayAs: today) && item.routineType == type && item.shouldApply
        }.sorted { $0.order < $1.order }
    }
    
    // MARK: - Products
    
    func addProduct(_ product: Product) {
        products.append(product)
        syncProductRoutineMembership(product)
        syncExclusions(for: product)
        rebuildSchedule(from: Date())
    }
    
    func updateProduct(_ product: Product) {
        if let idx = products.firstIndex(where: { $0.id == product.id }) {
            products[idx] = product
        }
        syncProductRoutineMembership(product)
        syncExclusions(for: product)
        rebuildSchedule(from: Date())
    }
    
    func updateProduct(productId: UUID, name: String? = nil, ingredients: [Ingredient]? = nil, frequencyDays: Int? = nil, routineTypes: Set<RoutineType>? = nil, excludedProductIds: Set<UUID>? = nil) {
        guard var product = product(by: productId) else { return }
        if let n = name { product.name = n }
        if let i = ingredients { product.ingredients = i }
        if let f = frequencyDays { product.frequencyDays = f }
        if let r = routineTypes { product.routineTypes = r }
        if let e = excludedProductIds {
            product.excludedProductIds = e
            syncExclusions(for: product)
        }
        updateProduct(product)
    }
    
    /// Keeps exclusions symmetric: if A excludes B, then B excludes A
    private func syncExclusions(for product: Product) {
        for excludedId in product.excludedProductIds {
            guard var other = self.product(by: excludedId) else { continue }
            if !other.excludedProductIds.contains(product.id) {
                other.excludedProductIds.insert(product.id)
                if let idx = self.products.firstIndex(where: { $0.id == other.id }) {
                    products[idx] = other
                }
            }
        }
        for otherId in products.map(\.id) where otherId != product.id {
            guard var other = self.product(by: otherId) else { continue }
            if other.excludedProductIds.contains(product.id) && !product.excludedProductIds.contains(otherId) {
                other.excludedProductIds.remove(product.id)
                if let idx = products.firstIndex(where: { $0.id == other.id }) {
                    products[idx] = other
                }
            }
        }
    }
    
    /// Syncs routine membership to match product.routineTypes: adds to routines in set, removes from others
    private func syncProductRoutineMembership(_ product: Product) {
        for type in RoutineType.allCases {
            var routine = routine(for: type) ?? Routine(type: type)
            let shouldBeInRoutine = product.routineTypes.contains(type)
            let isInRoutine = routine.productIds.contains(product.id)
            
            if shouldBeInRoutine && !isInRoutine {
                routine.productIds.append(product.id)
                updateRoutine(routine)
            } else if !shouldBeInRoutine && isInRoutine {
                routine.productIds.removeAll { $0 == product.id }
                updateRoutine(routine)
            }
        }
    }
    
    func updateProductFrequency(productId: UUID, useEveryDays: Int) {
        updateProduct(productId: productId, frequencyDays: useEveryDays)
    }
    
    func removeProduct(_ product: Product) {
        products.removeAll { $0.id == product.id }
        for idx in products.indices {
            var p = products[idx]
            p.excludedProductIds.remove(product.id)
            products[idx] = p
        }
        routines = routines.map { routine in
            var r = routine
            r.productIds = r.productIds.filter { $0 != product.id }
            return r
        }
        rebuildSchedule(from: Date())
    }
    
    func deleteProducts(at offsets: IndexSet) {
        for index in offsets {
            removeProduct(products[index])
        }
    }
    
    func product(by id: UUID) -> Product? {
        products.first { $0.id == id }
    }
    
    // MARK: - Routines
    
    func addRoutine(_ routine: Routine) {
        routines.append(routine)
    }
    
    func updateRoutine(_ routine: Routine) {
        if let idx = routines.firstIndex(where: { $0.id == routine.id }) {
            routines[idx] = routine
        } else {
            routines.append(routine)
        }
        rebuildSchedule(from: Date())
    }
    
    func updateRoutine(_ type: RoutineType, productIds: [UUID]) {
        var routine = routine(for: type) ?? Routine(type: type)
        let previousIds = Set(routine.productIds)
        routine.productIds = productIds
        updateRoutine(routine)
        
        // When removing a product from a routine, update the product's routineTypes
        for removedId in previousIds.subtracting(productIds) {
            guard var product = product(by: removedId) else { continue }
            product.routineTypes.remove(type)
            if let idx = products.firstIndex(where: { $0.id == product.id }) {
                products[idx] = product
            }
        }
        rebuildSchedule(from: Date())
    }
    
    func routine(for type: RoutineType) -> Routine? {
        routines.first { $0.type == type }
    }
    
    // MARK: - Schedule / Put Off
    
    func putOff(_ item: ScheduleItem, routineType: RoutineType, newFrequency: Int? = nil) {
        guard var product = product(by: item.productId) else { return }
        product.lastUsedDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        if let freq = newFrequency {
            product.frequencyDays = freq
        }
        updateProduct(product)
    }
    
    func putOff(productId: UUID, newFrequency: Int?) {
        guard let product = product(by: productId) else { return }
        var updatedProduct = product
        updatedProduct.lastUsedDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        if let freq = newFrequency {
            updatedProduct.frequencyDays = freq
        }
        updateProduct(updatedProduct)
    }
    
    func rebuildSchedule(from date: Date) {
        scheduleItems = generateSchedule(from: date, daysAhead: 14)
    }
    
    func generateSchedule(from startDate: Date, daysAhead: Int) -> [ScheduleItem] {
        var items: [ScheduleItem] = []
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        
        for dayOffset in 0..<daysAhead {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay) else { continue }
            
            for routine in routines {
                for (order, productId) in routine.productIds.enumerated() {
                    guard let product = product(by: productId) else { continue }
                    
                    let shouldApply = shouldApplyProduct(product, on: date, routine: routine)
                    items.append(ScheduleItem(
                        productId: productId,
                        productName: product.name,
                        product: product,
                        date: date,
                        routineType: routine.type,
                        order: order,
                        shouldApply: shouldApply,
                        wasPutOff: false
                    ))
                }
            }
        }
        
        return items
    }
    
    private func shouldApplyProduct(_ product: Product, on date: Date, routine: Routine) -> Bool {
        let calendar = Calendar.current
        let refDate = product.lastUsedDate ?? calendar.startOfDay(for: date)
        let daysSince = calendar.dateComponents([.day], from: refDate, to: date).day ?? 0
        guard daysSince >= 0 else { return false }
        
        // Check if product is in an exclusion group within this routine
        let group = exclusionGroup(for: product, in: routine)
        if group.count <= 1 {
            return daysSince % product.frequencyDays == 0
        }
        
        // Phase-based staggering: product p applies when daysSince % F == phase
        // e.g. 2 products, F=2: phase 0 on days 0,2,4; phase 1 on days 1,3,5
        let phase = exclusionGroupPhase(for: product, in: group, routine: routine)
        let f = product.frequencyDays
        return daysSince % f == phase
    }
    
    /// Products in the same routine that exclude each other (transitive)
    private func exclusionGroup(for product: Product, in routine: Routine) -> [UUID] {
        let inRoutine = routine.productIds.compactMap { self.product(by: $0) }
        var group: Set<UUID> = [product.id]
        var changed = true
        while changed {
            changed = false
            for p in inRoutine where !group.contains(p.id) {
                let connectsToGroup = group.contains { gid in
                    guard let g = self.product(by: gid) else { return false }
                    return g.excludedProductIds.contains(p.id) || p.excludedProductIds.contains(g.id)
                }
                if connectsToGroup {
                    group.insert(p.id)
                    changed = true
                }
            }
        }
        return routine.productIds.filter { group.contains($0) }
    }
    
    private func exclusionGroupPhase(for product: Product, in group: [UUID], routine: Routine) -> Int {
        let ordered = group.compactMap { id -> (UUID, Int)? in
            guard let idx = routine.productIds.firstIndex(of: id) else { return nil }
            return (id, idx)
        }.sorted { $0.1 < $1.1 }.map(\.0)
        return ordered.firstIndex(of: product.id) ?? 0
    }
    
    init() {
        rebuildSchedule(from: Date())
    }
    
    // MARK: - Reminders
    
    func reminderConfig(for type: RoutineType) -> ReminderConfig {
        reminderConfigs.first { $0.routineType == type } ?? ReminderConfig(routineType: type)
    }
    
    func updateReminderConfig(_ config: ReminderConfig) {
        if let idx = reminderConfigs.firstIndex(where: { $0.routineType == config.routineType }) {
            reminderConfigs[idx] = config
        } else {
            reminderConfigs.append(config)
        }
    }
}
