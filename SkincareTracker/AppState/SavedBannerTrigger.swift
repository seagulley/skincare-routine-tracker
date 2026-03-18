//
//  SavedBannerTrigger.swift
//  SkincareTracker
//
//  Triggers a banner at the bottom of the screen. Used for save confirmations and warnings.
//

import SwiftUI

@MainActor
final class SavedBannerTrigger: ObservableObject {
    @Published var isShowing = false
    @Published var message = "Saved"
    @Published var isSuccess = true

    func show(_ message: String = "Saved", success: Bool = true) {
        self.message = message
        self.isSuccess = success
        withAnimation(.easeInOut(duration: 0.25)) { isShowing = true }
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation(.easeInOut(duration: 0.25)) { isShowing = false }
        }
    }
}
