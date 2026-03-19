//
//  ViewRenderingTests.swift
//  SkincareTrackerTests
//
//  Renders SwiftUI views to increase line coverage. Views are instantiated with
//  a store and their body is evaluated via UIHostingController.
//

import XCTest
import SwiftUI
import UIKit
@testable import SkincareTracker

@MainActor
final class ViewRenderingTests: XCTestCase {

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

    private func render(_ view: some View) {
        let hosting = UIHostingController(rootView: view)
        _ = hosting.view
    }

    func testContentView_renders() throws {
        render(ContentView())
    }

    func testTodayView_renders() throws {
        render(TodayView().environmentObject(store).environmentObject(savedBanner))
    }

    func testCycleView_renders() throws {
        render(CycleView().environmentObject(store).environmentObject(savedBanner))
    }

    func testCycleView_withProducts_rendersLegend() throws {
        let product = Product(name: "Serum", ingredientNames: [])
        store.addProduct(product)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 0, routineType: .morning)
        render(CycleView().environmentObject(store).environmentObject(savedBanner))
    }

    func testCycleView_withManyProducts_rendersAllRows() throws {
        for i in 1...10 {
            let product = Product(name: "Product \(i)", ingredientNames: [])
            store.addProduct(product)
            store.addProductToCycle(product)
        }
        render(CycleView().environmentObject(store).environmentObject(savedBanner))
        XCTAssertEqual(store.productsInCycleOrdered.count, 10)
        XCTAssertEqual(CycleViewLayout.productListRowHeight, 58, "Row height must be 58 to prevent last product from being cut off")
    }

    func testProductsView_renders() throws {
        render(ProductsView().environmentObject(store).environmentObject(savedBanner))
    }

    func testProductsView_withProducts_rendersList() throws {
        store.addProduct(Product(name: "A", ingredientNames: []))
        store.addProduct(Product(name: "B", ingredientNames: ["X"]))
        render(ProductsView().environmentObject(store).environmentObject(savedBanner))
    }

    func testScheduleView_renders() throws {
        render(ScheduleView().environmentObject(store))
    }

    func testScheduleView_withItems_rendersList() throws {
        let product = Product(name: "Serum", ingredientNames: [])
        store.addProduct(product)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 0, routineType: .morning)
        store.saveCycle()
        render(ScheduleView().environmentObject(store))
    }

    func testRemindersView_renders() throws {
        render(
            RemindersView()
                .environmentObject(store)
                .environmentObject(ReminderService())
                .environmentObject(HealthKitService())
        )
    }

    func testAddProductView_renders() throws {
        render(AddProductView().environmentObject(store).environmentObject(savedBanner))
    }

    func testProductDetailView_renders() throws {
        let product = Product(name: "Vitamin C", ingredientNames: ["C", "E"])
        render(
            NavigationStack {
                ProductDetailView(product: product)
                    .environmentObject(store)
                    .environmentObject(savedBanner)
            }
        )
    }

    func testProductDetailView_emptyIngredients_renders() throws {
        let product = Product(name: "Simple", ingredientNames: [])
        render(
            NavigationStack {
                ProductDetailView(product: product)
                    .environmentObject(store)
                    .environmentObject(savedBanner)
            }
        )
    }

    func testEditProductView_renders() throws {
        let product = Product(name: "Edit Me", ingredientNames: [])
        store.addProduct(product)
        render(EditProductView(product: product).environmentObject(store).environmentObject(savedBanner))
    }

    func testPutOffSheetView_renders() throws {
        let product = Product(name: "Serum", ingredientNames: [])
        store.addProduct(product)
        store.assignProductToCycleSlot(productId: product.id, dayIndex: 0, routineType: .morning)
        store.saveCycle()
        let item = store.scheduleItems.first { $0.productId == product.id && $0.routineType == .morning }!
        render(
            PutOffSheetView(item: item, routineType: .morning, onDismiss: {})
                .environmentObject(store)
                .environmentObject(savedBanner)
        )
    }

    func testProductRowView_renders() throws {
        let product = Product(name: "Serum", ingredientNames: ["A", "B"])
        render(ProductRowView(product: product))
    }

    func testProductRowView_emptyIngredients_renders() throws {
        let product = Product(name: "Simple", ingredientNames: [])
        render(ProductRowView(product: product))
    }

    func testScheduleRowView_renders() throws {
        let product = Product(name: "Serum", ingredientNames: [])
        let item = ScheduleItem(
            productId: product.id,
            productName: product.name,
            product: product,
            date: Date(),
            routineType: .morning,
            order: 0,
            shouldApply: true
        )
        render(ScheduleRowView(item: item))
    }
}
