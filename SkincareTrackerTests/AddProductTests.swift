import XCTest
import UIKit
@testable import SkincareTracker

// MARK: - Image Picker Cancel Behavior
// When user cancels camera or photo library, they should return to Add Product page,
// not exit the sheet entirely. The fix: Coordinator must not call picker.dismiss().

@MainActor
final class ImagePickerCancelTests: XCTestCase {

    /// Mock picker that records whether dismiss(animated:completion:) was called.
    private final class MockImagePicker: UIImagePickerController {
        var dismissCallCount = 0
        override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
            dismissCallCount += 1
        }
    }

    func testImagePickerCancel_camera_returnsToAddProduct() throws {
        var onCancelCalled = false
        let coordinator = ImagePickerView.Coordinator(
            onImagePicked: { _ in },
            onCancel: { onCancelCalled = true }
        )
        let mockPicker = MockImagePicker()

        coordinator.imagePickerControllerDidCancel(mockPicker)

        XCTAssertTrue(onCancelCalled, "onCancel should be invoked when user cancels camera")
        XCTAssertEqual(mockPicker.dismissCallCount, 0, "Must not call picker.dismiss — it cascades and closes Add Product sheet")
    }

    func testImagePickerCancel_photoLibrary_returnsToAddProduct() throws {
        var onCancelCalled = false
        let coordinator = ImagePickerView.Coordinator(
            onImagePicked: { _ in },
            onCancel: { onCancelCalled = true }
        )
        let mockPicker = MockImagePicker()

        coordinator.imagePickerControllerDidCancel(mockPicker)

        XCTAssertTrue(onCancelCalled, "onCancel should be invoked when user cancels photo library")
        XCTAssertEqual(mockPicker.dismissCallCount, 0, "Must not call picker.dismiss — it cascades and closes Add Product sheet")
    }

    func testImagePickerDidFinishPicking_noImage_callsOnCancel() throws {
        var onCancelCalled = false
        var imagePicked: UIImage?
        let coordinator = ImagePickerView.Coordinator(
            onImagePicked: { imagePicked = $0 },
            onCancel: { onCancelCalled = true }
        )
        let mockPicker = MockImagePicker()
        let info: [UIImagePickerController.InfoKey: Any] = [:]  // No .originalImage

        coordinator.imagePickerController(mockPicker, didFinishPickingMediaWithInfo: info)

        XCTAssertTrue(onCancelCalled)
        XCTAssertNil(imagePicked)
    }

    func testImagePickerDidFinishPicking_withImage_callsOnImagePicked() throws {
        var imagePicked: UIImage?
        let coordinator = ImagePickerView.Coordinator(
            onImagePicked: { imagePicked = $0 },
            onCancel: { }
        )
        let mockPicker = MockImagePicker()
        let testImage = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { _ in }
        let info: [UIImagePickerController.InfoKey: Any] = [.originalImage: testImage]

        coordinator.imagePickerController(mockPicker, didFinishPickingMediaWithInfo: info)

        XCTAssertNotNil(imagePicked)
        XCTAssertEqual(imagePicked?.size.width, 10)
    }
}

// MARK: - Product Logic

@MainActor
final class AddProductTests: XCTestCase {

    var store: AppStore!

    override func setUpWithError() throws {
        store = AppStore()
    }

    override func tearDownWithError() throws {
        store = nil
    }

    // MARK: - Product Logic

    func testAddProduct_addsProductToProducts() throws {
        let product = Product(name: "Vitamin C Serum", ingredientNames: ["Vitamin C", "Ferulic Acid"])

        store.addProduct(product)

        XCTAssertEqual(store.products.count, 1)
        let added = store.product(by: product.id)!
        XCTAssertEqual(added.name, "Vitamin C Serum")
        XCTAssertEqual(added.ingredients.count, 2)
    }

    func testUpdateProduct_modifiesExistingProduct() throws {
        let product = Product(name: "Original", ingredientNames: [])
        store.addProduct(product)

        store.updateProduct(productId: product.id, name: "Updated")

        let updated = store.product(by: product.id)!
        XCTAssertEqual(updated.name, "Updated")
    }

    func testRemoveProduct_removesFromListAndRoutines() throws {
        let product = Product(name: "To Remove", ingredientNames: [])
        store.addProduct(product)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 0, routineType: .morning)
        store.saveCycle()

        store.removeProduct(product)

        XCTAssertEqual(store.products.count, 0)
        XCTAssertTrue(store.morningRoutine.productIds.isEmpty)
    }

    // MARK: - Put Off

    func testPutOff_hidesProductToday() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let product = Product(name: "Serum", ingredientNames: [])
        store.addProduct(product)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 0, routineType: .morning)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 1, routineType: .morning)
        store.saveCycle()

        let todayMorning = store.scheduleItems.filter { item in
            calendar.isDate(item.date, inSameDayAs: today) && item.routineType == .morning
        }
        let todayItem = todayMorning.first { $0.productId == product.id }!
        XCTAssertTrue(todayItem.shouldApply, "Product should apply today before put off")

        store.putOff(todayItem, routineType: .morning)

        store.rebuildSchedule(from: today)
        let todayMorningAfter = store.scheduleItems.filter { item in
            calendar.isDate(item.date, inSameDayAs: today) && item.routineType == .morning
        }
        let todayItemAfter = todayMorningAfter.first { $0.productId == product.id }!
        XCTAssertFalse(todayItemAfter.shouldApply, "Product should be hidden today after put off")

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let tomorrowMorning = store.scheduleItems.filter { item in
            calendar.isDate(item.date, inSameDayAs: tomorrow) && item.routineType == .morning
        }
        let tomorrowItem = tomorrowMorning.first { $0.productId == product.id }
        XCTAssertNotNil(tomorrowItem)
        XCTAssertTrue(tomorrowItem!.shouldApply, "Product should apply tomorrow")
    }

    // MARK: - Routine Logic

    func testUpdateRoutine_setsProductOrder() throws {
        let product1 = Product(name: "First", ingredientNames: [])
        let product2 = Product(name: "Second", ingredientNames: [])

        store.addProduct(product1)
        store.addProduct(product2)
        store.updateRoutine(.morning, productIds: [product1.id, product2.id])

        XCTAssertEqual(store.morningRoutine.productIds, [product1.id, product2.id])
    }

    func testDeleteProducts_atOffsets() throws {
        let p1 = Product(name: "A", ingredientNames: [])
        let p2 = Product(name: "B", ingredientNames: [])
        let p3 = Product(name: "C", ingredientNames: [])
        store.addProduct(p1)
        store.addProduct(p2)
        store.addProduct(p3)

        store.deleteProducts(at: IndexSet(integer: 1), from: store.sortedProducts)

        XCTAssertEqual(store.products.count, 2)
        XCTAssertFalse(store.products.contains(p2))
    }

    func testUpdateProduct_withIngredients() throws {
        let product = Product(name: "Original", ingredientNames: ["A"])
        store.addProduct(product)

        store.updateProduct(productId: product.id, ingredients: [Ingredient(name: "B")])

        let updated = store.product(by: product.id)!
        XCTAssertEqual(updated.ingredients.count, 1)
        XCTAssertEqual(updated.ingredients.first?.name, "B")
    }

    func testAddRoutine_addsToRoutines() throws {
        let routine = Routine(type: .morning, productIds: [])
        store.addRoutine(routine)
        XCTAssertTrue(store.routines.contains { $0.type == .morning })
    }

    func testRoutine_for_returnsCorrectRoutine() throws {
        let product = Product(name: "Serum", ingredientNames: [])
        store.addProduct(product)
        store.updateRoutine(.morning, productIds: [product.id])

        let morning = store.routine(for: .morning)
        XCTAssertNotNil(morning)
        XCTAssertEqual(morning!.type, .morning)
        XCTAssertEqual(morning!.productIds, [product.id])

        let night = store.routine(for: .night)
        XCTAssertTrue(night == nil || night!.productIds.isEmpty)
    }

    func testRemoveProduct_clearsPutOffRecords() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let product = Product(name: "Serum", ingredientNames: [])
        store.addProduct(product)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 0, routineType: .morning)
        store.saveCycle()

        let item = store.scheduleItems.first { $0.productId == product.id }!
        store.putOff(item, routineType: .morning)
        store.removeProduct(product)

        let newProduct = Product(name: "New", ingredientNames: [])
        store.addProduct(newProduct)
        store.assignProductToCycleSlot(productId: newProduct.id, dayIndex: 0, routineType: .morning)
        store.saveCycle()
        store.rebuildSchedule(from: today)
        let newItem = store.scheduleItems.first { $0.productId == newProduct.id }!
        XCTAssertTrue(newItem.shouldApply, "New product should apply; put-off records for removed product should not affect others")
    }

    func testSortedProducts_returnsByNameOrder() throws {
        store.addProduct(Product(name: "Zebra", ingredientNames: []))
        store.addProduct(Product(name: "Alpha", ingredientNames: []))
        store.addProduct(Product(name: "Midi", ingredientNames: []))

        let names = store.sortedProducts.map(\.name)
        XCTAssertEqual(names, ["Alpha", "Midi", "Zebra"])
    }

    func testProduct_nilReturnsForUnknownId() throws {
        XCTAssertNil(store.product(by: UUID()))
    }

    func testUpdateRoutine_updatesProductIds() throws {
        let product = Product(name: "Serum", ingredientNames: [])
        store.addProduct(product)
        store.updateRoutine(.morning, productIds: [product.id])
        store.updateRoutine(.night, productIds: [product.id])

        XCTAssertEqual(store.morningRoutine.productIds, [product.id])
        XCTAssertEqual(store.nightRoutine.productIds, [product.id])

        store.updateRoutine(.morning, productIds: [])
        XCTAssertTrue(store.morningRoutine.productIds.isEmpty)
        XCTAssertEqual(store.nightRoutine.productIds, [product.id])
    }

    // MARK: - AppStore Extended Coverage

    func testProductColor_nilWhenNotInCycle() throws {
        let product = Product(name: "Serum", ingredientNames: [])
        store.addProduct(product)
        XCTAssertNil(store.productColor(for: product))
    }

    func testProductColor_returnsColorWhenInCycle() throws {
        let product = Product(name: "Serum", ingredientNames: [])
        store.addProduct(product)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 0, routineType: .morning)
        XCTAssertNotNil(store.productColor(for: product))
    }

    func testProductsInCycle_sortedByName() throws {
        let a = Product(name: "Zebra", ingredientNames: [])
        let b = Product(name: "Alpha", ingredientNames: [])
        store.addProduct(a)
        store.addProduct(b)
        store.assignProductToCycleSlot(productId: a.id, dayIndex: 0, routineType: .morning)
        store.assignProductToCycleSlot(productId: b.id, dayIndex: 0, routineType: .morning)
        store.saveCycle()
        let inCycle = store.productsInCycle.map(\.name)
        XCTAssertEqual(inCycle, ["Alpha", "Zebra"])
    }

    func testProductsNotInCycle_excludesAssignedProducts() throws {
        let a = Product(name: "A", ingredientNames: [])
        let b = Product(name: "B", ingredientNames: [])
        store.addProduct(a)
        store.addProduct(b)
        store.assignProductToCycleSlot(productId: a.id, dayIndex: 0, routineType: .morning)
        store.saveCycle()
        let notInCycle = store.productsNotInCycle.map(\.name)
        XCTAssertEqual(notInCycle, ["B"])
    }

    func testProductsInCycleOrdered_followsCycleOrder() throws {
        let a = Product(name: "A", ingredientNames: [])
        let b = Product(name: "B", ingredientNames: [])
        store.addProduct(a)
        store.addProduct(b)
        store.assignProductToCycleSlot(productId: a.id, dayIndex: 0, routineType: .morning)
        store.assignProductToCycleSlot(productId: b.id, dayIndex: 0, routineType: .morning)
        store.saveCycle()
        store.moveProductInCycleOrder(from: IndexSet(integer: 1), to: 0)
        let ordered = store.productsInCycleOrdered.map(\.name)
        XCTAssertEqual(ordered, ["B", "A"])
    }

    func testAddProductToCycle_ignoresProductNotInStore() throws {
        let product = Product(name: "Orphan", ingredientNames: [])
        store.addProductToCycle(product)
        XCTAssertTrue(store.cycleProductOrder.isEmpty)
    }

    func testAddProductToCycle_ignoresProductAlreadyInCycle() throws {
        let product = Product(name: "Serum", ingredientNames: [])
        store.addProduct(product)
        store.addProductToCycle(product)
        let countBefore = store.cycleProductOrder.count
        store.addProductToCycle(product)
        XCTAssertEqual(store.cycleProductOrder.count, countBefore)
    }

    func testMoveProductInCycleOrder_reordersList() throws {
        let a = Product(name: "A", ingredientNames: [])
        let b = Product(name: "B", ingredientNames: [])
        store.addProduct(a)
        store.addProduct(b)
        store.assignProductToCycleSlot(productId: a.id, dayIndex: 0, routineType: .morning)
        store.assignProductToCycleSlot(productId: b.id, dayIndex: 0, routineType: .morning)
        store.saveCycle()
        store.moveProductInCycleOrder(from: IndexSet(integer: 1), to: 0)
        XCTAssertEqual(store.productsInCycleOrdered.map(\.name), ["B", "A"])
    }

    func testMoveProductInCycleOrder_emptyList_returnsEarly() throws {
        store.moveProductInCycleOrder(from: IndexSet(integer: 0), to: 0)
        XCTAssertTrue(store.cycleProductOrder.isEmpty)
    }

    func testUpdateProduct_fullProductReplacement() throws {
        let product = Product(name: "Original", ingredientNames: ["A"])
        store.addProduct(product)
        var updated = product
        updated.name = "Updated"
        updated.ingredients = [Ingredient(name: "B")]
        store.updateProduct(updated)
        let fetched = store.product(by: product.id)!
        XCTAssertEqual(fetched.name, "Updated")
        XCTAssertEqual(fetched.ingredients.map(\.name), ["B"])
    }

    func testUpdateRoutine_byRoutineObject_updatesExisting() throws {
        let routine = Routine(type: .morning, productIds: [])
        store.addRoutine(routine)
        let product = Product(name: "P", ingredientNames: [])
        store.addProduct(product)
        var updated = routine
        updated.productIds = [product.id]
        store.updateRoutine(updated)
        XCTAssertEqual(store.routine(for: .morning)?.productIds, [product.id])
    }

    func testUpdateRoutine_byRoutineObject_appendsWhenNew() throws {
        let product = Product(name: "P", ingredientNames: [])
        store.addProduct(product)
        let routine = Routine(type: .morning, productIds: [product.id])
        store.updateRoutine(routine)
        XCTAssertEqual(store.routine(for: .morning)?.productIds, [product.id])
    }

    func testGenerateSchedule_emptyCycle_returnsEmpty() throws {
        let items = store.generateSchedule(from: Date(), daysAhead: 14)
        XCTAssertTrue(items.isEmpty)
    }

    func testPutOff_productNotFound_returnsEarly() throws {
        let item = ScheduleItem(productId: UUID(), productName: "Ghost", date: Date(), routineType: .morning, order: 0, shouldApply: true)
        store.putOff(item, routineType: .morning)
        XCTAssertEqual(store.scheduleItems.count, 0)
    }

    func testAssignProductToCycleSlot_invalidDayIndex_returnsEarly() throws {
        let product = Product(name: "P", ingredientNames: [])
        store.addProduct(product)
        store.cycleLength = 7
        store.assignProductToCycleSlot(productId: product.id, dayIndex: -1, routineType: .morning)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 10, routineType: .morning)
        XCTAssertTrue(store.productsOnCycleSlot(dayIndex: 0, routineType: .morning).isEmpty)
    }

    func testAssignProductToCycleSlot_productNotFound_returnsEarly() throws {
        store.cycleLength = 7
        store.assignProductToCycleSlot(productId: UUID(), dayIndex: 0, routineType: .morning)
        XCTAssertTrue(store.cycleAssignments.isEmpty)
    }

    func testAssignProductToCycleSlot_duplicate_ignored() throws {
        let product = Product(name: "P", ingredientNames: [])
        store.addProduct(product)
        store.cycleLength = 7
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 0, routineType: .morning)
        let idsBefore = store.productsOnCycleSlot(dayIndex: 0, routineType: .morning)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 0, routineType: .morning)
        let idsAfter = store.productsOnCycleSlot(dayIndex: 0, routineType: .morning)
        XCTAssertEqual(idsBefore.count, idsAfter.count)
    }

    func testClearProductFromCycle_removesFromAllSlots() throws {
        let product = Product(name: "P", ingredientNames: [])
        store.addProduct(product)
        store.cycleLength = 3
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 0, routineType: .morning)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 1, routineType: .night)
        store.saveCycle()
        store.clearProductFromCycle(productId: product.id)
        XCTAssertTrue(store.productsOnCycleSlot(dayIndex: 0, routineType: .morning).isEmpty)
        XCTAssertTrue(store.productsOnCycleSlot(dayIndex: 1, routineType: .night).isEmpty)
        XCTAssertNil(store.productColor(for: product))
    }

    func testCycleDayIndex_noCycle_returnsZero() throws {
        store.cycleLength = 7
        let idx = store.cycleDayIndex(for: Date())
        XCTAssertEqual(idx, 0)
    }

    func testProductsForDate_returnsProductsForThatCycleDay() throws {
        let product = Product(name: "P", ingredientNames: [])
        store.addProduct(product)
        store.cycleLength = 7
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 2, routineType: .morning)
        store.cycleStartDate = Calendar.current.startOfDay(for: Date())
        let twoDaysLater = Calendar.current.date(byAdding: .day, value: 2, to: store.cycleStartDate!)!
        let products = store.productsForDate(twoDaysLater, routineType: .morning)
        XCTAssertEqual(products.map(\.name), ["P"])
    }

    func testSetCycleLength_clampsToValidRange() throws {
        store.setCycleLength(1)
        XCTAssertEqual(store.cycleLength, 2)
        store.setCycleLength(20)
        XCTAssertEqual(store.cycleLength, 14)
    }

    func testUpdateProduct_withCategoryId() throws {
        let product = Product(name: "P", ingredientNames: [])
        store.addProduct(product)
        store.updateProduct(productId: product.id, categoryId: "serum")
        XCTAssertEqual(store.product(by: product.id)?.categoryId, "serum")
    }

    func testUpdateProduct_withCategoryIdNil_keepsExisting() throws {
        let product = Product(name: "P", ingredientNames: [], categoryId: "serum")
        store.addProduct(product)
        store.updateProduct(productId: product.id, name: "Renamed")
        XCTAssertEqual(store.product(by: product.id)?.categoryId, "serum")
    }

    func testTodayMorningItems_filteredAndSorted() throws {
        let product = Product(name: "P", ingredientNames: [])
        store.addProduct(product)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 0, routineType: .morning)
        store.saveCycle()
        let items = store.todayMorningItems
        XCTAssertTrue(items.allSatisfy { $0.routineType == .morning && $0.shouldApply })
    }

    func testTodayNightItems_filteredAndSorted() throws {
        let product = Product(name: "P", ingredientNames: [])
        store.addProduct(product)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 0, routineType: .night)
        store.saveCycle()
        let items = store.todayNightItems
        XCTAssertTrue(items.allSatisfy { $0.routineType == .night && $0.shouldApply })
    }

    func testUpdateReminderConfig_addsNewWhenMissing() throws {
        store.updateReminderConfig(ReminderConfig(routineType: .morning, hour: 10, minute: 15))
        let config = store.reminderConfig(for: .morning)
        XCTAssertEqual(config.hour, 10)
        XCTAssertEqual(config.minute, 15)
    }

    func testToggleProductOnCycleSlot_productNotFound_returnsEarly() throws {
        store.cycleLength = 7
        store.toggleProductOnCycleSlot(productId: UUID(), dayIndex: 0, routineType: .morning)
        XCTAssertTrue(store.cycleAssignments.isEmpty)
    }

    func testUnassignProductFromCycleSlot_emptiesSlot_removesKey() throws {
        let product = Product(name: "P", ingredientNames: [])
        store.addProduct(product)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 1, routineType: .night)
        XCTAssertFalse(store.productsOnCycleSlot(dayIndex: 1, routineType: .night).isEmpty)
        store.unassignProductFromCycleSlot(productId: product.id, dayIndex: 1, routineType: .night)
        XCTAssertNil(store.cycleAssignments["1-Night"])
    }

    func testProductsSortedByCycleOrder_emptyOrder_sortsByCategory() throws {
        let toner = Product(name: "Toner", ingredientNames: [], categoryId: "toner")
        let serum = Product(name: "Serum", ingredientNames: [], categoryId: "serum")
        store.addProduct(serum)
        store.addProduct(toner)
        let sorted = store.productsSortedByCycleOrder([serum, toner])
        XCTAssertEqual(sorted.map(\.name), ["Toner", "Serum"])
    }

    func testAssignProductToCycleSlot_maxProductsPerSlot_capsAt20() throws {
        let products = (0..<22).map { Product(name: "P\($0)", ingredientNames: []) }
        products.forEach { store.addProduct($0) }
        store.cycleLength = 7
        for i in 0..<22 {
            store.assignProductToCycleSlot(productId: products[i].id, dayIndex: 0, routineType: .morning)
        }
        let slot = store.productsOnCycleSlot(dayIndex: 0, routineType: .morning)
        XCTAssertEqual(slot.count, 20)
    }

    func testUpdateProduct_productNotInStore_ignored() throws {
        let product = Product(name: "Orphan", ingredientNames: [])
        store.updateProduct(product)
        XCTAssertEqual(store.products.count, 0)
    }

    func testRemoveProduct_productNotInStore_clearsFromCycle() throws {
        let product = Product(name: "P", ingredientNames: [])
        store.addProduct(product)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 0, routineType: .morning)
        store.saveCycle()
        let otherProduct = Product(name: "Other", ingredientNames: [])
        store.removeProduct(otherProduct)
        XCTAssertTrue(store.productsOnCycleSlot(dayIndex: 0, routineType: .morning).contains(product.id))
    }
}

// MARK: - Reminder Tests

@MainActor
final class ReminderTests: XCTestCase {
    var store: AppStore!

    override func setUpWithError() throws {
        store = AppStore()
    }

    override func tearDownWithError() throws {
        store = nil
    }

    func testReminderConfig_returnsDefaultForMissing() throws {
        let config = store.reminderConfig(for: .morning)
        XCTAssertEqual(config.routineType, .morning)
    }

    func testUpdateReminderConfig_updatesConfig() throws {
        let config = ReminderConfig(routineType: .morning, hour: 9, minute: 30)
        store.updateReminderConfig(config)

        let updated = store.reminderConfig(for: .morning)
        XCTAssertEqual(updated.hour, 9)
        XCTAssertEqual(updated.minute, 30)
    }
}

// MARK: - Model Tests

@MainActor
final class ModelTests: XCTestCase {
    func testIngredient_init() throws {
        let ing = Ingredient(name: "Vitamin C")
        XCTAssertEqual(ing.name, "Vitamin C")
    }

    func testReminderConfig_init() throws {
        let config = ReminderConfig(routineType: .night, hour: 22, minute: 30)
        XCTAssertEqual(config.routineType, .night)
        XCTAssertEqual(config.hour, 22)
        XCTAssertEqual(config.minute, 30)
    }

    func testReminderConfig_codableRoundTrip() throws {
        let config = ReminderConfig(routineType: .morning, hour: 9, minute: 15, isEnabled: true)
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ReminderConfig.self, from: data)
        XCTAssertEqual(decoded.routineType, config.routineType)
        XCTAssertEqual(decoded.hour, 9)
        XCTAssertEqual(decoded.minute, 15)
        XCTAssertEqual(decoded.isEnabled, true)
    }

    func testReminderConfig_decodeWithoutOptionalKeys_defaultsToFalse() throws {
        let id = UUID()
        let json = "{\"id\":\"\(id.uuidString)\",\"routineType\":\"Night\",\"hour\":22,\"minute\":0,\"isEnabled\":true}"
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(ReminderConfig.self, from: data)
        XCTAssertFalse(config.useHealthWakeTime)
        XCTAssertFalse(config.useHealthBedtime)
    }

    func testRoutine_init() throws {
        let routine = Routine(type: .morning, productIds: [])
        XCTAssertEqual(routine.type, .morning)
        XCTAssertTrue(routine.productIds.isEmpty)
    }

    func testScheduleItem_init() throws {
        let item = ScheduleItem(productId: UUID(), productName: "Test", date: Date(), routineType: .morning, order: 0, shouldApply: true)
        XCTAssertEqual(item.productName, "Test")
        XCTAssertEqual(item.routineType, .morning)
        XCTAssertTrue(item.shouldApply)
    }
}
