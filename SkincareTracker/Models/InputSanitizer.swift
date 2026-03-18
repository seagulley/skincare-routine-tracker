//
//  InputSanitizer.swift
//  SkincareTracker
//
//  Validates and sanitizes user input to prevent injection attacks and malformed data.
//

import Foundation

/// Sanitizes user input to prevent injection, control-character, and resource-exhaustion attacks.
enum InputSanitizer {

    /// Max length for product names.
    private static let maxProductNameLength = 200

    /// Max length for full ingredient list text.
    private static let maxIngredientListLength = 10_000


    /// Validates a product name. Returns nil if valid, or an error message if invalid.
    static func validateProductName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Product name cannot be empty." }
        if trimmed.count > maxProductNameLength {
            return "Product name is too long (max \(maxProductNameLength) characters)."
        }
        if containsDangerousCharacters(trimmed) {
            return "Product name contains invalid characters. Use only letters, numbers, and common punctuation."
        }
        return nil
    }

    /// Validates ingredient list text before parsing. Returns nil if valid, or an error message if invalid.
    static func validateIngredientList(_ text: String) -> String? {
        if text.count > maxIngredientListLength {
            return "Ingredient list is too long (max \(maxIngredientListLength) characters)."
        }
        if containsDangerousCharacters(text) {
            return "Ingredient list contains invalid characters (e.g. control characters, <, >, backticks)."
        }
        return nil
    }

    /// Sanitizes a string for safe display/error messages: removes control chars and null bytes.
    /// Use when interpolating user input into error messages or logs.
    static func sanitizeForDisplay(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\0", with: "")
            .unicodeScalars
            .filter { !CharacterSet.controlCharacters.contains($0) }
            .map { String($0) }
            .joined()
    }

    /// Returns true if the string contains characters that could be used for injection.
    private static func containsDangerousCharacters(_ string: String) -> Bool {
        if string.contains("\0") { return true }
        if string.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
            return true
        }
        // Angle brackets, backticks, backslash - common injection vectors
        if string.contains("<") || string.contains(">") || string.contains("`") || string.contains("\\") {
            return true
        }
        return false
    }
}
