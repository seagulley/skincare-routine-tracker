import XCTest
@testable import SkincareTracker

@MainActor
final class CycleTests: XCTestCase {

    var store: AppStore!
    var savedBanner: SavedBannerTrigger!

    override func setUpWithError() throws {
        store = AppStore()
        savedBanner = SavedBannerTrigger()
    }

    override func tearDownWithError() throws {
        store = nil
        savedBanner = nil
    }

    // MARK: - Save Cycle (Empty)

    func testTrySaveCycle_emptyCycle_showsCycleIsEmptyBanner() throws {
        // cycleAssignments is empty by default
        store.trySaveCycle(using: savedBanner)

        XCTAssertEqual(savedBanner.message, "Cycle is empty", "Should show Cycle is empty message")
        XCTAssertFalse(savedBanner.isSuccess, "Should indicate failure/warning")
        XCTAssertTrue(savedBanner.isShowing, "Banner should be visible")
    }

    func testTrySaveCycle_emptyCycle_doesNotSave() throws {
        store.trySaveCycle(using: savedBanner)

        XCTAssertNil(store.cycleStartDate, "Should not set cycleStartDate when cycle is empty")
    }

    func testTrySaveCycle_withAssignments_showsSavedBanner() throws {
        let product = Product(name: "Serum", ingredientNames: [])
        store.addProduct(product)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 0, routineType: .morning)

        store.trySaveCycle(using: savedBanner)

        XCTAssertEqual(savedBanner.message, "Saved", "Should show Saved message")
        XCTAssertTrue(savedBanner.isSuccess, "Should indicate success")
        XCTAssertTrue(savedBanner.isShowing, "Banner should be visible")
    }

    func testTrySaveCycle_withAssignments_savesCycle() throws {
        let product = Product(name: "Serum", ingredientNames: [])
        store.addProduct(product)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 0, routineType: .morning)

        store.trySaveCycle(using: savedBanner)

        XCTAssertNotNil(store.cycleStartDate, "Should set cycleStartDate when cycle has assignments")
    }

    // MARK: - "Today" Day Selection (Set as today via context menu)

    func testCurrentCycleDayIndex_noCycleSet_returnsNil() throws {
        store.cycleLength = 7
        XCTAssertNil(store.currentCycleDayIndex, "When no cycle is saved, currentCycleDayIndex should be nil")
    }

    func testSetTodayToCycleDay_setsCycleStartDateSoDayIsToday() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        store.cycleLength = 7

        store.setTodayToCycleDay(0)

        XCTAssertNotNil(store.cycleStartDate)
        XCTAssertEqual(store.currentCycleDayIndex, 0, "Day 0 should be today")
        XCTAssertTrue(calendar.isDate(store.cycleStartDate!, inSameDayAs: today), "cycleStartDate should be today when day 0 is today")
    }

    func testSetTodayToCycleDay_dayTwo_setsCycleStartDateTwoDaysAgo() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        store.cycleLength = 7

        store.setTodayToCycleDay(2)

        XCTAssertNotNil(store.cycleStartDate)
        XCTAssertEqual(store.currentCycleDayIndex, 2, "Day 2 should be today")
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        XCTAssertTrue(calendar.isDate(store.cycleStartDate!, inSameDayAs: twoDaysAgo), "cycleStartDate should be 2 days ago")
    }

    func testSetTodayToCycleDay_rebuildsSchedule() throws {
        let product = Product(name: "Serum", ingredientNames: [])
        store.addProduct(product)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 1, routineType: .morning)
        store.cycleLength = 3

        store.setTodayToCycleDay(1)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayMorning = store.scheduleItems.filter { item in
            calendar.isDate(item.date, inSameDayAs: today) && item.routineType == .morning
        }
        let serumItem = todayMorning.first { $0.productId == product.id }
        XCTAssertTrue(serumItem?.shouldApply ?? false, "Product on day 1 should apply today when day 1 is set as today")
    }

    func testSetTodayToCycleDay_respectsCycleLength() throws {
        store.cycleLength = 5
        store.setTodayToCycleDay(4)

        XCTAssertEqual(store.currentCycleDayIndex, 4, "Day 4 should be today in 5-day cycle")
    }

    // MARK: - Cycle Slot Assignment

    func testAssignProductToCycleSlot_addsProductToSlot() throws {
        let product = Product(name: "Serum", ingredientNames: [])
        store.addProduct(product)
        store.cycleLength = 7

        store.assignProductToCycleSlot(productId: product.id, dayIndex: 0, routineType: .morning)

        let ids = store.productsOnCycleSlot(dayIndex: 0, routineType: .morning)
        XCTAssertTrue(ids.contains(product.id), "Product should be assigned to day 0 morning")
    }

    func testToggleProductOnCycleSlot_addsAndRemoves() throws {
        let product = Product(name: "Serum", ingredientNames: [])
        store.addProduct(product)
        store.cycleLength = 7

        store.toggleProductOnCycleSlot(productId: product.id, dayIndex: 1, routineType: .morning)
        XCTAssertTrue(store.productsOnCycleSlot(dayIndex: 1, routineType: .morning).contains(product.id))

        store.toggleProductOnCycleSlot(productId: product.id, dayIndex: 1, routineType: .morning)
        XCTAssertFalse(store.productsOnCycleSlot(dayIndex: 1, routineType: .morning).contains(product.id))
    }

    // MARK: - Apply Cycle to Routines

    func testApplyCycleToRoutines_updatesRoutinesFromAssignments() throws {
        let productA = Product(name: "A", ingredientNames: [])
        let productB = Product(name: "B", ingredientNames: [])
        store.addProduct(productA)
        store.addProduct(productB)
        store.cycleLength = 3

        store.assignProductToCycleSlot(productId: productA.id, dayIndex: 0, routineType: .morning)
        store.assignProductToCycleSlot(productId: productB.id, dayIndex: 0, routineType: .night)
        store.assignProductToCycleSlot(productId: productA.id, dayIndex: 1, routineType: .night)

        store.applyCycleToRoutines()

        XCTAssertTrue(store.morningRoutine.productIds.contains(productA.id), "A should be in morning routine")
        XCTAssertTrue(store.nightRoutine.productIds.contains(productA.id), "A should be in night routine (day 1)")
        XCTAssertTrue(store.nightRoutine.productIds.contains(productB.id), "B should be in night routine")
    }

    func testApplyCycleToRoutines_emptyCycle_clearsRoutines() throws {
        let product = Product(name: "Serum", ingredientNames: [])
        store.addProduct(product)
        store.updateRoutine(.morning, productIds: [product.id])
        store.updateRoutine(.night, productIds: [product.id])

        store.cycleLength = 7
        // No cycle assignments
        store.applyCycleToRoutines()

        XCTAssertTrue(store.morningRoutine.productIds.isEmpty, "Morning routine should be empty")
        XCTAssertTrue(store.nightRoutine.productIds.isEmpty, "Night routine should be empty")
    }

    // MARK: - Save Cycle

    func testSaveCycle_setsCycleStartDate() throws {
        let product = Product(name: "Serum", ingredientNames: [])
        store.addProduct(product)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 0, routineType: .morning)

        store.saveCycle()

        XCTAssertNotNil(store.cycleStartDate, "cycleStartDate should be set after save")
    }

    func testSaveCycle_scheduleReflectsCycleAssignments() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let productA = Product(name: "A", ingredientNames: [])
        let productB = Product(name: "B", ingredientNames: [])
        store.addProduct(productA)
        store.addProduct(productB)
        store.cycleLength = 2

        store.assignProductToCycleSlot(productId: productA.id, dayIndex: 0, routineType: .morning)
        store.assignProductToCycleSlot(productId: productB.id, dayIndex: 1, routineType: .morning)

        store.cycleStartDate = today
        store.rebuildSchedule(from: today)

        let todayMorning = store.scheduleItems.filter { item in
            calendar.isDate(item.date, inSameDayAs: today) && item.routineType == .morning
        }
        let todayA = todayMorning.first { $0.productId == productA.id }
        let todayB = todayMorning.first { $0.productId == productB.id }
        XCTAssertTrue(todayA?.shouldApply ?? false, "A should apply today (cycle day 0)")
        XCTAssertFalse(todayB?.shouldApply ?? false, "B should not apply today (cycle day 0); no item = doesn't apply")

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let tomorrowMorning = store.scheduleItems.filter { item in
            calendar.isDate(item.date, inSameDayAs: tomorrow) && item.routineType == .morning
        }
        let tomorrowA = tomorrowMorning.first { $0.productId == productA.id }
        let tomorrowB = tomorrowMorning.first { $0.productId == productB.id }
        XCTAssertFalse(tomorrowA?.shouldApply ?? false, "A should not apply tomorrow (cycle day 1); no item = doesn't apply")
        XCTAssertTrue(tomorrowB?.shouldApply ?? false, "B should apply tomorrow (cycle day 1)")
    }

    func testSaveCycle_appliesCycleToRoutinesAndRebuildsSchedule() throws {
        let product = Product(name: "Serum", ingredientNames: [])
        store.addProduct(product)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 0, routineType: .morning)

        store.saveCycle()

        XCTAssertTrue(store.morningRoutine.productIds.contains(product.id), "Product should be in morning routine after save")
    }

    func testSaveCycle_preservesTodayDayWhenAlreadySet() throws {
        let product = Product(name: "Serum", ingredientNames: [])
        store.addProduct(product)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 0, routineType: .morning)
        store.cycleLength = 7

        store.saveCycle()
        let startAfterFirstSave = store.cycleStartDate!
        store.setTodayToCycleDay(3)
        let startAfterSetToday = store.cycleStartDate!

        store.saveCycle()

        XCTAssertEqual(
            store.cycleStartDate,
            startAfterSetToday,
            "Save should preserve which day is today (Day 3), not reset to Day 1"
        )
        XCTAssertNotEqual(
            store.cycleStartDate,
            startAfterFirstSave,
            "cycleStartDate should differ from first save (Day 1) since we set Day 3 as today"
        )
    }

    // MARK: - Cycle Length

    func testSetCycleLength_prunesAssignmentsForRemovedDays() throws {
        let product = Product(name: "Serum", ingredientNames: [])
        store.addProduct(product)
        store.cycleLength = 7
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 5, routineType: .morning)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 2, routineType: .morning)

        store.setCycleLength(4)

        XCTAssertTrue(store.productsOnCycleSlot(dayIndex: 2, routineType: .morning).contains(product.id))
        XCTAssertFalse(store.productsOnCycleSlot(dayIndex: 5, routineType: .morning).contains(product.id), "Day 5 assignment should be pruned")
    }

    func testUnassignProductFromCycleSlot_removesProduct() throws {
        let product = Product(name: "Serum", ingredientNames: [])
        store.addProduct(product)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 2, routineType: .night)

        store.unassignProductFromCycleSlot(productId: product.id, dayIndex: 2, routineType: .night)

        XCTAssertFalse(store.productsOnCycleSlot(dayIndex: 2, routineType: .night).contains(product.id))
    }

    func testCycleSchedule_putOffRespected() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let product = Product(name: "Serum", ingredientNames: [])
        store.addProduct(product)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 0, routineType: .morning)
        store.cycleStartDate = today
        store.rebuildSchedule(from: today)

        let todayMorning = store.scheduleItems.first { item in
            calendar.isDate(item.date, inSameDayAs: today) && item.routineType == .morning && item.productId == product.id
        }!
        store.putOff(todayMorning, routineType: .morning)

        store.rebuildSchedule(from: today)
        let afterPutOff = store.scheduleItems.first { item in
            calendar.isDate(item.date, inSameDayAs: today) && item.routineType == .morning && item.productId == product.id
        }!
        XCTAssertFalse(afterPutOff.shouldApply, "Put-off product should not apply")
    }
}
