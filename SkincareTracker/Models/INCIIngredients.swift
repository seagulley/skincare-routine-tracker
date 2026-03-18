//
//  INCIIngredients.swift
//  SkincareTracker
//
//  Parses user-entered ingredient names into standardized INCI (International Nomenclature
//  of Cosmetic Ingredients) names. Uses a local alias map—no external API.
//

import Foundation

/// Errors returned when ingredient parsing detects invalid or unrecognizable input.
enum IngredientParseError: LocalizedError {
    case invalidCharacters(reason: String)
    case unusualDelimiters(reason: String)
    case unidentifiableIngredients([String])

    var errorDescription: String? {
        switch self {
        case .invalidCharacters(let reason):
            return reason
        case .unusualDelimiters(let reason):
            return "Invalid format: \(reason) Use commas to separate ingredients."
        case .unidentifiableIngredients(let names):
            let safe = names.prefix(5).map { InputSanitizer.sanitizeForDisplay($0) }
            let list = safe.joined(separator: ", ")
            let more = names.count > 5 ? " and \(names.count - 5) more" : ""
            return "Unrecognized ingredient\(names.count == 1 ? "" : "s"): \(list)\(more). Check spelling or use standard INCI names."
        }
    }
}

/// Parses raw ingredient lists into standardized INCI names.
enum INCIIngredients {

    /// Maps common aliases (lowercased) to canonical INCI names.
    /// Add more entries as needed. Unknown ingredients pass through trimmed.
    private static let aliasToINCI: [String: String] = [
        // Vitamin C and derivatives
        "vitamin c": "Ascorbic Acid",
        "l-ascorbic acid": "Ascorbic Acid",
        "ascorbic acid": "Ascorbic Acid",
        "l ascorbic acid": "Ascorbic Acid",
        "sodium ascorbyl phosphate": "Sodium Ascorbyl Phosphate",
        "sap": "Sodium Ascorbyl Phosphate",
        "magnesium ascorbyl phosphate": "Magnesium Ascorbyl Phosphate",
        "map": "Magnesium Ascorbyl Phosphate",
        "ascorbyl glucoside": "Ascorbyl Glucoside",
        "ethyl ascorbic acid": "Ethyl Ascorbic Acid",
        "tetrahexyldecyl ascorbate": "Tetrahexyldecyl Ascorbate",
        "ascorbyl tetraisopalmitate": "Ascorbyl Tetraisopalmitate",

        // Vitamin A / retinoids
        "vitamin a": "Retinol",
        "retinol": "Retinol",
        "retinal": "Retinal",
        "retinaldehyde": "Retinal",
        "retinoid": "Retinol",
        "retinyl retinoate": "Retinyl Retinoate",
        "adapalene": "Adapalene",
        "tretinoin": "Tretinoin",
        "retinoic acid": "Tretinoin",
        "bakuchiol": "Bakuchiol",

        // Niacinamide / Vitamin B3
        "niacinamide": "Niacinamide",
        "vitamin b3": "Niacinamide",
        "nicotinamide": "Niacinamide",

        // Panthenol / Vitamin B5
        "panthenol": "Panthenol",
        "vitamin b5": "Panthenol",
        "d-panthenol": "Panthenol",
        "provitamin b5": "Panthenol",

        // Vitamin E
        "vitamin e": "Tocopherol",
        "tocopherol": "Tocopherol",
        "alpha tocopherol": "Tocopherol",
        "tocopheryl acetate": "Tocopheryl Acetate",
        "vitamin e acetate": "Tocopheryl Acetate",

        // Acids
        "hyaluronic acid": "Hyaluronic Acid",
        "ha": "Hyaluronic Acid",
        "sodium hyaluronate": "Sodium Hyaluronate",
        "ferulic acid": "Ferulic Acid",
        "salicylic acid": "Salicylic Acid",
        "bha": "Salicylic Acid",
        "beta hydroxy acid": "Salicylic Acid",
        "glycolic acid": "Glycolic Acid",
        "lactic acid": "Lactic Acid",
        "mandelic acid": "Mandelic Acid",
        "citric acid": "Citric Acid",
        "azelaic acid": "Azelaic Acid",
        "kojic acid": "Kojic Acid",
        "alpha hydroxy acid": "Glycolic Acid",
        "aha": "Glycolic Acid",

        // Brightening / pigmentation
        "alpha arbutin": "Alpha-Arbutin",
        "arbutin": "Alpha-Arbutin",
        "tranexamic acid": "Tranexamic Acid",
        "licorice": "Glycyrrhiza Glabra Root Extract",
        "licorice root": "Glycyrrhiza Glabra Root Extract",
        "glycyrrhiza glabra": "Glycyrrhiza Glabra Root Extract",

        // Hydrators / humectants
        "glycerin": "Glycerin",
        "glycerol": "Glycerin",
        "squalane": "Squalane",
        "squalene": "Squalane",
        "ceramide": "Ceramide NP",
        "ceramides": "Ceramide NP",

        // Centella / cica
        "centella": "Centella Asiatica Extract",
        "cica": "Centella Asiatica Extract",
        "centella asiatica": "Centella Asiatica Extract",
        "gotu kola": "Centella Asiatica Extract",
        "tiger grass": "Centella Asiatica Extract",
        "madecassoside": "Madecassoside",
        "asiaticoside": "Asiaticoside",

        // Antioxidants / botanicals
        "resveratrol": "Resveratrol",
        "green tea": "Camellia Sinensis Leaf Extract",
        "camellia sinensis": "Camellia Sinensis Leaf Extract",
        "egcg": "Camellia Sinensis Leaf Extract",
        "caffeine": "Caffeine",
        "coenzyme q10": "Ubiquinone",
        "coq10": "Ubiquinone",
        "ubiquinone": "Ubiquinone",

        // Peptides
        "peptide": "Palmitoyl Pentapeptide-4",
        "peptides": "Palmitoyl Pentapeptide-4",
        "matrixyl": "Palmitoyl Pentapeptide-4",
        "palmitoyl pentapeptide": "Palmitoyl Pentapeptide-4",
        "palmitoyl tetrapeptide": "Palmitoyl Tetrapeptide-7",
        "copper peptide": "Copper Tripeptide-1",
        "ghk-cu": "Copper Tripeptide-1",

        // Barrier / soothing
        "allantoin": "Allantoin",
        "bisabolol": "Bisabolol",
        "alpha bisabolol": "Bisabolol",
        "chamomile": "Chamomilla Recutita Extract",
        "aloe vera": "Aloe Barbadensis Leaf Extract",
        "aloe": "Aloe Barbadensis Leaf Extract",
        "oat": "Avena Sativa Kernel Extract",
        "colloidal oatmeal": "Avena Sativa Kernel Extract",
        "oat extract": "Avena Sativa Kernel Extract",

        // Sunscreen / minerals
        "zinc oxide": "Zinc Oxide",
        "titanium dioxide": "Titanium Dioxide",
        "benzoyl peroxide": "Benzoyl Peroxide",

        // Medicinal / pharmaceutical excipients
        "stearic acid": "Stearic Acid",
        "isopropyl myristate": "Isopropyl Myristate",
        "polyoxyl 40 stearate": "Polyoxyl 40 Stearate",
        "polyoxyethylene 40 stearate": "Polyoxyl 40 Stearate",
        "stearyl alcohol": "Stearyl Alcohol",
        "xanthan gum": "Xanthan Gum",
        "sorbic acid": "Sorbic Acid",
        "butylated hydroxytoluene": "BHT",
        "bht": "BHT",
        "purified water": "Aqua",
        "deionized water": "Aqua",
        "distilled water": "Aqua",
        "propylene glycol": "Propylene Glycol",
        "mineral oil": "Mineral Oil",
        "white petrolatum": "Petrolatum",
        "petrolatum": "Petrolatum",
        "cetyl alcohol": "Cetyl Alcohol",
        "cetearyl alcohol": "Cetearyl Alcohol",
        "sodium benzoate": "Sodium Benzoate",
        "edta": "EDTA",
        "disodium edta": "Disodium EDTA",

        // Misc common
        "water": "Aqua",
        "aqua": "Aqua",
        "fragrance": "Parfum",
        "parfum": "Parfum",
        "snail mucin": "Snail Secretion Filtrate",
        "snail filtrate": "Snail Secretion Filtrate",
        "collagen": "Collagen",
        "silicon": "Dimethicone",
        "dimethicone": "Dimethicone",
    ]

    /// Parses and validates ingredient text. Returns an error if unusual delimiters
    /// or unidentifiable ingredients are detected.
    /// - Parameter rawText: User input, e.g. "Tretinoin 0.025%, stearic acid, and purified water"
    /// - Returns: `.success([Ingredient])` or `.failure(IngredientParseError)`
    static func parseValidated(_ rawText: String) -> Result<[Ingredient], IngredientParseError> {
        if let charError = InputSanitizer.validateIngredientList(rawText).map({ IngredientParseError.invalidCharacters(reason: $0) }) {
            return .failure(charError)
        }

        let normalized = normalizeForParsing(rawText)

        if let delimiterError = validateDelimiters(rawText) {
            return .failure(delimiterError)
        }

        let rawNames = splitIngredientNames(normalized)
        var unidentifiable: [String] = []

        for raw in rawNames {
            let (base, _) = extractConcentration(raw)
            if !isKnown(base) {
                unidentifiable.append(raw.trimmingCharacters(in: .whitespaces))
            }
        }

        if !unidentifiable.isEmpty {
            return .failure(.unidentifiableIngredients(unidentifiable))
        }

        return .success(parse(normalized))
    }

    /// Parses ingredient text without validation. Use for tests or when validation is bypassed.
    static func parse(_ rawText: String) -> [Ingredient] {
        let rawNames = splitIngredientNames(rawText)
        var seen = Set<String>()
        var result: [Ingredient] = []

        for raw in rawNames {
            let (base, concentration) = extractConcentration(raw)
            let inci = toINCI(base)
            let displayName = concentration.map { "\(inci) \($0)" } ?? inci
            // Dedupe by display name so "Tretinoin 0.025%" and "Tretinoin 0.1%" are both kept
            let key = displayName.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                result.append(Ingredient(name: displayName))
            }
        }
        return result
    }

    /// Extracts concentration suffix (e.g. "0.025%") from raw ingredient; returns (baseName, concentration?).
    private static func extractConcentration(_ raw: String) -> (base: String, concentration: String?) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        // Match patterns like "0.025%", "1%", "2.5%", "0.1%" at end of string
        let pattern = #"\s+(\d+(?:\.\d+)?\s*%)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              let range = Range(match.range(at: 1), in: trimmed) else {
            return (trimmed, nil)
        }
        let concentration = String(trimmed[range])
        let base = String(trimmed[..<trimmed.index(trimmed.startIndex, offsetBy: match.range.location)]).trimmingCharacters(in: .whitespaces)
        return (base, concentration)
    }

    /// Normalizes OCR or pasted text (newlines, semicolons) to comma-separated form for parsing.
    static func normalizeForParsing(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: ", ")
            .replacingOccurrences(of: ";", with: ", ")
            .replacingOccurrences(of: "  ", with: " ")
    }

    /// Converts a single raw name (without concentration) to its INCI form.
    static func toINCI(_ raw: String) -> String {
        let key = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard !key.isEmpty else { return raw }
        return aliasToINCI[key] ?? raw.trimmingCharacters(in: .whitespaces)
    }

    /// Returns true if the ingredient (base name, without concentration) is in our alias map.
    private static func isKnown(_ raw: String) -> Bool {
        let key = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard !key.isEmpty else { return false }
        return aliasToINCI[key] != nil
    }

    /// Splits by comma, trims "and " prefix from segments.
    private static func splitIngredientNames(_ text: String) -> [String] {
        text
            .split(separator: ",")
            .map { part in
                var s = part.trimmingCharacters(in: .whitespaces)
                if s.lowercased().hasPrefix("and ") {
                    s = String(s.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                }
                return s
            }
            .filter { !$0.isEmpty }
    }

    /// Returns an error if the input uses unusual delimiters or looks like non-ingredient text.
    private static func validateDelimiters(_ text: String) -> IngredientParseError? {
        if text.contains("|") {
            return .unusualDelimiters(reason: "Pipe (|) is not supported.")
        }
        if text.contains("\t") {
            return .unusualDelimiters(reason: "Tabs are not supported.")
        }
        if text.lowercased().contains("http") || text.contains("@") {
            return .unusualDelimiters(reason: "This looks like a URL or email, not an ingredient list.")
        }
        if text.contains("\\") {
            return .unusualDelimiters(reason: "Backslashes are not supported.")
        }
        return nil
    }
}
