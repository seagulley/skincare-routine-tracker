//
//  IngredientLabelScanner.swift
//  SkincareTracker
//
//  Extracts text from product label images using on-device Vision OCR.
//

import Foundation
import Vision
import UIKit

/// On-device OCR for ingredient labels. No network calls.
enum IngredientLabelScanner {

    /// Extracts text from an image using Vision's text recognition.
    /// - Parameter image: The product label or ingredient list image
    /// - Returns: Recognized text, or nil if recognition fails
    static func extractText(from image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if error != nil {
                    continuation.resume(returning: nil)
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text.isEmpty ? nil : text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
