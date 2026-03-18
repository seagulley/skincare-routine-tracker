//
//  IngredientTests.swift
//  SkincareTrackerTests
//
//  Tests for ingredient parsing (INCI), normalization, label scanning, and Product/Ingredient models.
//

import XCTest
import UIKit
@testable import SkincareTracker

// MARK: - INCIIngredients Tests

final class INCIIngredientsTests: XCTestCase {

    func testParse_convertsAliasesToINCI() throws {
        let ingredients = INCIIngredients.parse("Vitamin C, Niacinamide, HA, Ferulic Acid")
        let names = ingredients.map(\.name)
        XCTAssertEqual(names, ["Ascorbic Acid", "Niacinamide", "Hyaluronic Acid", "Ferulic Acid"])
    }

    func testParse_unknownIngredientsPassThrough() throws {
        let ingredients = INCIIngredients.parse("Ascorbic Acid, Some Custom Ingredient")
        let names = ingredients.map(\.name)
        XCTAssertEqual(names[0], "Ascorbic Acid")
        XCTAssertEqual(names[1], "Some Custom Ingredient")
    }

    func testParse_deduplicatesAliases() throws {
        let ingredients = INCIIngredients.parse("Vitamin C, Ascorbic Acid, L-Ascorbic Acid")
        let names = ingredients.map(\.name)
        XCTAssertEqual(names, ["Ascorbic Acid"])
    }

    func testParse_emptyStringReturnsEmpty() throws {
        let ingredients = INCIIngredients.parse("")
        XCTAssertTrue(ingredients.isEmpty)
    }

    func testParse_caseInsensitiveLookup() throws {
        let ingredients = INCIIngredients.parse("VITAMIN C, vitamin b3")
        let names = ingredients.map(\.name)
        XCTAssertEqual(names, ["Ascorbic Acid", "Niacinamide"])
    }

    func testToINCI_singleIngredient() throws {
        XCTAssertEqual(INCIIngredients.toINCI("Vitamin C"), "Ascorbic Acid")
        XCTAssertEqual(INCIIngredients.toINCI("Unknown Ingredient"), "Unknown Ingredient")
    }

    func testParse_medicinalList_withConcentrationAndAnd() throws {
        let input = "Tretinoin 0.025%, stearic acid, isopropyl myristate, polyoxyl 40 stearate, stearyl alcohol, xanthan gum, sorbic acid, butylated hydroxytoluene, and purified water"
        let ingredients = INCIIngredients.parse(input)
        let names = ingredients.map(\.name)
        XCTAssertEqual(names[0], "Tretinoin 0.025%")
        XCTAssertEqual(names[1], "Stearic Acid")
        XCTAssertEqual(names[2], "Isopropyl Myristate")
        XCTAssertEqual(names[3], "Polyoxyl 40 Stearate")
        XCTAssertEqual(names[4], "Stearyl Alcohol")
        XCTAssertEqual(names[5], "Xanthan Gum")
        XCTAssertEqual(names[6], "Sorbic Acid")
        XCTAssertEqual(names[7], "BHT")
        XCTAssertEqual(names[8], "Aqua")
    }

    func testParse_preservesConcentration() throws {
        let ingredients = INCIIngredients.parse("Niacinamide 10%, Ascorbic Acid 15%")
        let names = ingredients.map(\.name)
        XCTAssertEqual(names, ["Niacinamide 10%", "Ascorbic Acid 15%"])
    }

    func testParse_differentConcentrationsBothKept() throws {
        let ingredients = INCIIngredients.parse("Tretinoin 0.025%, Tretinoin 0.1%")
        let names = ingredients.map(\.name)
        XCTAssertEqual(names, ["Tretinoin 0.025%", "Tretinoin 0.1%"])
    }

    func testParse_andBeforeLastItem() throws {
        let ingredients = INCIIngredients.parse("Water, Glycerin, and Niacinamide")
        let names = ingredients.map(\.name)
        XCTAssertEqual(names, ["Aqua", "Glycerin", "Niacinamide"])
    }

    func testParse_whitespaceOnlyReturnsEmpty() throws {
        let ingredients = INCIIngredients.parse("   ,  ,  ")
        XCTAssertTrue(ingredients.isEmpty)
    }

    func testParse_handlesExtraWhitespace() throws {
        let ingredients = INCIIngredients.parse("  Vitamin C  ,  Niacinamide  ")
        let names = ingredients.map(\.name)
        XCTAssertEqual(names, ["Ascorbic Acid", "Niacinamide"])
    }

    func testParse_botanicalAliases() throws {
        let ingredients = INCIIngredients.parse("Cica, Centella, Licorice")
        let names = ingredients.map(\.name)
        // Cica and Centella both map to Centella Asiatica Extract and dedupe to one
        XCTAssertEqual(names.count, 2)
        XCTAssertEqual(names[0], "Centella Asiatica Extract")
        XCTAssertEqual(names[1], "Glycyrrhiza Glabra Root Extract")
    }

    // MARK: - normalizeForParsing

    func testNormalizeForParsing_replacesNewlinesWithCommas() throws {
        let input = "Water\nGlycerin\nNiacinamide"
        let result = INCIIngredients.normalizeForParsing(input)
        XCTAssertEqual(result, "Water, Glycerin, Niacinamide")
    }

    func testNormalizeForParsing_replacesSemicolonsWithCommas() throws {
        let input = "Water; Glycerin; Niacinamide"
        let result = INCIIngredients.normalizeForParsing(input)
        XCTAssertEqual(result, "Water, Glycerin, Niacinamide")
    }

    func testNormalizeForParsing_parseAfterNormalize_producesCorrectIngredients() throws {
        let ocrStyleText = "Aqua\nGlycerin\nNiacinamide\nHyaluronic Acid"
        let normalized = INCIIngredients.normalizeForParsing(ocrStyleText)
        let ingredients = INCIIngredients.parse(normalized)
        let names = ingredients.map(\.name)
        XCTAssertEqual(names, ["Aqua", "Glycerin", "Niacinamide", "Hyaluronic Acid"])
    }

    func testParse_waterAliases() throws {
        XCTAssertEqual(INCIIngredients.toINCI("water"), "Aqua")
        XCTAssertEqual(INCIIngredients.toINCI("aqua"), "Aqua")
        XCTAssertEqual(INCIIngredients.toINCI("purified water"), "Aqua")
        XCTAssertEqual(INCIIngredients.toINCI("deionized water"), "Aqua")
    }

    // MARK: - parseValidated

    func testParseValidated_validIngredients_succeeds() throws {
        let result = INCIIngredients.parseValidated("Vitamin C, Niacinamide, HA")
        switch result {
        case .success(let ingredients):
            XCTAssertEqual(ingredients.map(\.name), ["Ascorbic Acid", "Niacinamide", "Hyaluronic Acid"])
        case .failure:
            XCTFail("Expected success")
        }
    }

    func testParseValidated_emptyString_succeeds() throws {
        let result = INCIIngredients.parseValidated("")
        switch result {
        case .success(let ingredients):
            XCTAssertTrue(ingredients.isEmpty)
        case .failure:
            XCTFail("Expected success for empty input")
        }
    }

    func testParseValidated_pipeDelimiter_fails() throws {
        let result = INCIIngredients.parseValidated("Water | Glycerin")
        switch result {
        case .success:
            XCTFail("Expected failure for pipe delimiter")
        case .failure(let error):
            if case .unusualDelimiters = error { } else {
                XCTFail("Expected unusualDelimiters error, got \(error)")
            }
            XCTAssertTrue(error.localizedDescription.contains("Pipe"))
        }
    }

    func testParseValidated_tabDelimiter_fails() throws {
        let result = INCIIngredients.parseValidated("Water\tGlycerin")
        switch result {
        case .success:
            XCTFail("Expected failure for tab delimiter")
        case .failure:
            // Tab is a control char → invalidCharacters, or could be unusualDelimiters; both reject it
            break
        }
    }

    func testParseValidated_urlInInput_fails() throws {
        let result = INCIIngredients.parseValidated("Water, Glycerin, http://example.com")
        switch result {
        case .success:
            XCTFail("Expected failure for URL in input")
        case .failure(let error):
            if case .unusualDelimiters = error { } else {
                XCTFail("Expected unusualDelimiters error, got \(error)")
            }
        }
    }

    func testParseValidated_unidentifiableIngredient_fails() throws {
        let result = INCIIngredients.parseValidated("Vitamin C, XyzzyUnknown, Niacinamide")
        switch result {
        case .success:
            XCTFail("Expected failure for unidentifiable ingredient")
        case .failure(let error):
            if case .unidentifiableIngredients(let names) = error {
                XCTAssertEqual(names, ["XyzzyUnknown"])
            } else {
                XCTFail("Expected unidentifiableIngredients error, got \(error)")
            }
            XCTAssertTrue(error.localizedDescription.contains("Unrecognized"))
        }
    }

    func testParseValidated_invalidCharacters_fails() throws {
        let result = INCIIngredients.parseValidated("Water, Glycerin<script>")
        switch result {
        case .success:
            XCTFail("Expected failure for angle brackets")
        case .failure(let error):
            if case .invalidCharacters = error { } else {
                XCTFail("Expected invalidCharacters error, got \(error)")
            }
        }
    }

    func testParseValidated_multipleUnidentifiable_fails() throws {
        let result = INCIIngredients.parseValidated("Vitamin C, Unknown1, Unknown2")
        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(let error):
            if case .unidentifiableIngredients(let names) = error {
                XCTAssertEqual(names, ["Unknown1", "Unknown2"])
            } else {
                XCTFail("Expected unidentifiableIngredients error")
            }
        }
    }
}

// MARK: - InputSanitizer Tests

final class InputSanitizerTests: XCTestCase {

    func testValidateProductName_empty_returnsError() throws {
        XCTAssertNotNil(InputSanitizer.validateProductName(""))
        XCTAssertNotNil(InputSanitizer.validateProductName("   "))
    }

    func testValidateProductName_valid_returnsNil() throws {
        XCTAssertNil(InputSanitizer.validateProductName("Vitamin C Serum"))
        XCTAssertNil(InputSanitizer.validateProductName("My Product (2024)"))
    }

    func testValidateProductName_angleBrackets_returnsError() throws {
        XCTAssertNotNil(InputSanitizer.validateProductName("Product <script>"))
        XCTAssertNotNil(InputSanitizer.validateProductName(">alert"))
    }

    func testValidateProductName_nullByte_returnsError() throws {
        XCTAssertNotNil(InputSanitizer.validateProductName("Product\u{0}Injection"))
    }

    func testValidateProductName_tooLong_returnsError() throws {
        let long = String(repeating: "a", count: 201)
        XCTAssertNotNil(InputSanitizer.validateProductName(long))
    }

    func testValidateIngredientList_valid_returnsNil() throws {
        XCTAssertNil(InputSanitizer.validateIngredientList("Water, Glycerin, Niacinamide"))
        XCTAssertNil(InputSanitizer.validateIngredientList(""))
    }

    func testValidateIngredientList_tooLong_returnsError() throws {
        let long = String(repeating: "a", count: 10_001)
        XCTAssertNotNil(InputSanitizer.validateIngredientList(long))
    }

    func testValidateIngredientList_angleBrackets_returnsError() throws {
        XCTAssertNotNil(InputSanitizer.validateIngredientList("Water, Glycerin<script>"))
    }

    func testValidateIngredientList_backticks_returnsError() throws {
        XCTAssertNotNil(InputSanitizer.validateIngredientList("Water `injection"))
    }

    func testValidateIngredientList_backslash_returnsError() throws {
        XCTAssertNotNil(InputSanitizer.validateIngredientList("Water\\Glycerin"))
    }

    func testSanitizeForDisplay_removesControlChars() throws {
        let input = "Hello\u{0}World\u{1}Test"
        let result = InputSanitizer.sanitizeForDisplay(input)
        XCTAssertFalse(result.contains("\u{0}"))
        XCTAssertFalse(result.contains("\u{1}"))
    }
}

// MARK: - Ingredient Model Tests

final class IngredientModelTests: XCTestCase {

    func testIngredient_initWithName() throws {
        let ing = Ingredient(name: "Ascorbic Acid")
        XCTAssertEqual(ing.name, "Ascorbic Acid")
        XCTAssertNotEqual(ing.id, UUID())
    }

    func testIngredient_initWithIdAndName() throws {
        let id = UUID()
        let ing = Ingredient(id: id, name: "Niacinamide")
        XCTAssertEqual(ing.id, id)
        XCTAssertEqual(ing.name, "Niacinamide")
    }

    func testIngredient_hashable() throws {
        let a = Ingredient(name: "A")
        let b = Ingredient(id: a.id, name: "A")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testIngredient_differentNamesNotEqual() throws {
        let a = Ingredient(name: "A")
        let b = Ingredient(name: "B")
        XCTAssertNotEqual(a, b)
    }

    func testIngredient_codableRoundTrip() throws {
        let ing = Ingredient(name: "Retinol")
        let data = try JSONEncoder().encode(ing)
        let decoded = try JSONDecoder().decode(Ingredient.self, from: data)
        XCTAssertEqual(decoded.name, ing.name)
    }
}

// MARK: - Product with Ingredients Tests

@MainActor
final class ProductIngredientsTests: XCTestCase {

    var store: AppStore!

    override func setUpWithError() throws {
        store = AppStore()
    }

    override func tearDownWithError() throws {
        store = nil
    }

    func testAddProduct_withParsedIngredients_storesINCINames() throws {
        let rawInput = "Vitamin C, HA, Niacinamide"
        let ingredients = INCIIngredients.parse(rawInput)
        let product = Product(name: "Serum", ingredients: ingredients, categoryId: "other")

        store.addProduct(product)

        let added = store.product(by: product.id)!
        XCTAssertEqual(added.ingredients.count, 3)
        XCTAssertEqual(added.ingredients.map(\.name), ["Ascorbic Acid", "Hyaluronic Acid", "Niacinamide"])
    }

    func testAddProduct_withIngredientNames_convenienceInit() throws {
        let product = Product(name: "Custom", ingredientNames: ["A", "B", "C"])

        store.addProduct(product)

        let added = store.product(by: product.id)!
        XCTAssertEqual(added.ingredients.count, 3)
        XCTAssertEqual(added.ingredients.map(\.name), ["A", "B", "C"])
    }

    func testUpdateProduct_replacesIngredients() throws {
        let product = Product(name: "Original", ingredientNames: ["A", "B"])
        store.addProduct(product)

        let newIngredients = INCIIngredients.parse("Vitamin C, Ferulic Acid")
        store.updateProduct(productId: product.id, ingredients: newIngredients)

        let updated = store.product(by: product.id)!
        XCTAssertEqual(updated.ingredients.count, 2)
        XCTAssertEqual(updated.ingredients.map(\.name), ["Ascorbic Acid", "Ferulic Acid"])
    }

    func testProduct_initWithIngredientNames_createsDistinctIds() throws {
        let product = Product(name: "Test", ingredientNames: ["A", "B"])
        let ids = Set(product.ingredients.map(\.id))
        XCTAssertEqual(ids.count, 2, "Each ingredient should have unique id")
    }

    func testProduct_codableRoundTrip_preservesIngredients() throws {
        let product = Product(name: "Serum", ingredientNames: ["Vitamin C", "Niacinamide"])
        let data = try JSONEncoder().encode(product)
        let decoded = try JSONDecoder().decode(Product.self, from: data)
        XCTAssertEqual(decoded.ingredients.count, 2)
        XCTAssertEqual(decoded.ingredients.map(\.name), ["Vitamin C", "Niacinamide"])
    }
}

// MARK: - IngredientLabelScanner Tests

final class IngredientLabelScannerTests: XCTestCase {

    func testExtractText_emptyImage_returnsNil() async throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        let text = await IngredientLabelScanner.extractText(from: image)
        // No text in solid color image; Vision may return nil or empty
        XCTAssertTrue(text == nil || text!.isEmpty)
    }

    func testExtractText_solidColorImage_doesNotCrash() async throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let image = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        let text = await IngredientLabelScanner.extractText(from: image)
        // Should complete without crashing; result may be nil or empty string
        _ = text
    }

    func testExtractText_imageWithText_completesWithoutCrash() async throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 50))
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 50))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18),
                .foregroundColor: UIColor.black
            ]
            "Aqua Glycerin Niacinamide".draw(in: CGRect(x: 10, y: 10, width: 180, height: 30), withAttributes: attrs)
        }
        let text = await IngredientLabelScanner.extractText(from: image)
        // Result may be nil, empty, or contain recognized text depending on Vision
        _ = text  // Method completes; result may be nil or recognized text
    }
}

// MARK: - ProductCategory Tests

final class ProductCategoryTests: XCTestCase {

    func testApplicationOrder_knownCategory() throws {
        XCTAssertEqual(ProductCategory.applicationOrder(for: "serum"), 4)
        XCTAssertEqual(ProductCategory.applicationOrder(for: "toner"), 0)
        XCTAssertEqual(ProductCategory.applicationOrder(for: "spf"), 9)
        XCTAssertEqual(ProductCategory.applicationOrder(for: "other"), 99)
    }

    func testApplicationOrder_nilOrUnknown_returns99() throws {
        XCTAssertEqual(ProductCategory.applicationOrder(for: nil), 99)
        XCTAssertEqual(ProductCategory.applicationOrder(for: "unknown"), 99)
    }

    func testUsesAlphabeticalTieBreak_serumActiveTreatment() throws {
        XCTAssertTrue(ProductCategory.usesAlphabeticalTieBreak(categoryId: "serum"))
        XCTAssertTrue(ProductCategory.usesAlphabeticalTieBreak(categoryId: "active"))
        XCTAssertTrue(ProductCategory.usesAlphabeticalTieBreak(categoryId: "treatment"))
    }

    func testUsesAlphabeticalTieBreak_other_returnsFalse() throws {
        XCTAssertFalse(ProductCategory.usesAlphabeticalTieBreak(categoryId: "other"))
        XCTAssertFalse(ProductCategory.usesAlphabeticalTieBreak(categoryId: "toner"))
    }

    func testCategory_nil_returnsOther() throws {
        let cat = ProductCategory.category(id: nil)
        XCTAssertEqual(cat.id, "other")
    }

    func testCategory_knownId_returnsCategory() throws {
        let cat = ProductCategory.category(id: "essence")
        XCTAssertEqual(cat.id, "essence")
        XCTAssertEqual(cat.name, "Essence")
    }

    func testForPicker_orderedByApplicationOrder() throws {
        let picker = ProductCategory.forPicker
        let orders = picker.map(\.applicationOrder)
        XCTAssertEqual(orders, orders.sorted())
    }
}

// MARK: - SavedBannerTrigger Tests

@MainActor
final class SavedBannerTriggerTests: XCTestCase {

    func testShow_defaultMessageAndSuccess() throws {
        let banner = SavedBannerTrigger()
        banner.show()
        XCTAssertEqual(banner.message, "Saved")
        XCTAssertTrue(banner.isSuccess)
        XCTAssertTrue(banner.isShowing)
    }

    func testShow_customMessageAndFailure() throws {
        let banner = SavedBannerTrigger()
        banner.show("Cycle is empty", success: false)
        XCTAssertEqual(banner.message, "Cycle is empty")
        XCTAssertFalse(banner.isSuccess)
        XCTAssertTrue(banner.isShowing)
    }
}

// MARK: - HealthKitService Tests

final class HealthKitServiceTests: XCTestCase {

    func testIsAvailable_returnsBool() throws {
        let result = HealthKitService.isAvailable
        XCTAssertTrue(result == true || result == false)
    }
}
