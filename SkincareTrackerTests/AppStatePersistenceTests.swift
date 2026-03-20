//
//  AppStatePersistenceTests.swift
//  SkincareTrackerTests
//
//  Verifies that app state is saved and restored correctly when the user exits the app.
//
//  To verify tests fail when persistence is NOT implemented:
//  1. In AppStore.init: comment out the "if let loaded = AppStatePersistence.load()" block
//  2. In AppStore.saveToDisk: add "return" as the first line (before AppStatePersistence.save)
//  3. Run: xcodebuild test -scheme SkincareTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SkincareTrackerTests/AppStatePersistenceTests
//  4. Expect: testSaveToDisk_writesStateFileToDisk, testSaveAndLoad_withCycleEdits_*, testSaveAndLoad_unsavedCycleEdits_* FAIL
//  5. Restore the persistence code; all tests should pass.
//

import XCTest
@testable import SkincareTracker

@MainActor
final class AppStatePersistenceTests: XCTestCase {

    private var testFileURL: URL!

    override func setUpWithError() throws {
        let tempDir = FileManager.default.temporaryDirectory
        testFileURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathComponent("app_state.json")
        try FileManager.default.createDirectory(at: testFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        AppStatePersistence.fileURLOverride = testFileURL
    }

    override func tearDownWithError() throws {
        AppStatePersistence.fileURLOverride = nil
        try? FileManager.default.removeItem(at: testFileURL)
        try? FileManager.default.removeItem(at: testFileURL.deletingLastPathComponent())
    }

    // MARK: - Save Writes to Disk

    /// Fails when saveToDisk is a no-op (fix not implemented). The state file must exist after save.
    func testSaveToDisk_writesStateFileToDisk() throws {
        let store = AppStore()
        store.addProduct(Product(name: "Test", ingredientNames: []))
        store.saveToDisk()

        XCTAssertTrue(FileManager.default.fileExists(atPath: testFileURL.path),
                      "saveToDisk must write app_state.json when app exits; fails when persistence is not implemented")
    }

    // MARK: - No Edits (Empty State)

    /// When the user exits with no data and no edits, save preserves empty state and load restores it.
    func testSaveAndLoad_emptyState_preservesEmptyStateAfterAppExit() throws {
        let store = AppStore()
        XCTAssertTrue(store.products.isEmpty, "Fresh store should have no products")
        XCTAssertTrue(store.cycleAssignments.isEmpty, "Fresh store should have no cycle assignments")

        store.saveToDisk()

        let restoredStore = AppStore()
        XCTAssertTrue(restoredStore.products.isEmpty, "After app exit, products should remain empty")
        XCTAssertTrue(restoredStore.cycleAssignments.isEmpty, "After app exit, cycle assignments should remain empty")
        XCTAssertNil(restoredStore.cycleStartDate, "After app exit, cycleStartDate should remain nil")
    }

    // MARK: - With Edits (Cycle + Products)

    /// When the user adds products, configures the cycle, and exits, state is restored on next launch.
    func testSaveAndLoad_withCycleEdits_restoresStateAfterAppExit() throws {
        let product = Product(name: "Vitamin C Serum", ingredientNames: ["Vitamin C", "Hyaluronic Acid"])
        let store = AppStore()
        store.addProduct(product)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 0, routineType: .morning)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 1, routineType: .night)
        store.setCycleLength(7)
        store.saveCycle()

        store.saveToDisk()

        let restoredStore = AppStore()
        XCTAssertEqual(restoredStore.products.count, 1, "Product should be restored")
        XCTAssertEqual(restoredStore.sortedProducts.first?.name, "Vitamin C Serum", "Product name should match")
        XCTAssertTrue(restoredStore.productsOnCycleSlot(dayIndex: 0, routineType: .morning).contains(product.id), "Day 0 morning assignment should be restored")
        XCTAssertTrue(restoredStore.productsOnCycleSlot(dayIndex: 1, routineType: .night).contains(product.id), "Day 1 night assignment should be restored")
        XCTAssertNotNil(restoredStore.cycleStartDate, "cycleStartDate should be restored")
        XCTAssertEqual(restoredStore.cycleLength, 7, "cycleLength should be restored")
    }

    /// When the user makes edits but does not tap Save in the Cycle UI, unsaved cycle changes are still persisted on app exit.
    func testSaveAndLoad_unsavedCycleEdits_persistsOnAppExit() throws {
        let product = Product(name: "Retinol", ingredientNames: [])
        let store = AppStore()
        store.addProduct(product)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 2, routineType: .morning)
        XCTAssertTrue(store.hasUnsavedCycleChanges, "Assigning without save should mark unsaved")

        store.saveToDisk()

        let restoredStore = AppStore()
        XCTAssertTrue(restoredStore.productsOnCycleSlot(dayIndex: 2, routineType: .morning).contains(product.id),
                     "Unsaved cycle edits should be persisted when app exits (saveToDisk called on background)")
    }
}
