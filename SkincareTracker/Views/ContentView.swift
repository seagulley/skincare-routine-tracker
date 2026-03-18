//
//  ContentView.swift
//  SkincareTracker
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = AppStore()
    @StateObject private var savedBanner = SavedBannerTrigger()
    @StateObject private var reminderService = ReminderService()
    @StateObject private var healthKitService = HealthKitService()
    @State private var showOnboarding = !OnboardingView.hasCompletedOnboarding

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }

            CycleView()
                .tabItem { Label("Cycle", systemImage: "arrow.2.circlepath") }
            
            ProductsView()
                .tabItem { Label("Products", systemImage: "drop.fill") }
            
            RemindersView()
                .tabItem { Label("Reminders", systemImage: "bell.fill") }
        }
        .foregroundStyle(AppColors.textPrimary)
        .background(AppColors.background)
        .tint(AppColors.accent)
        .environmentObject(store)
        .environmentObject(savedBanner)
        .environmentObject(reminderService)
        .environmentObject(healthKitService)
        .overlay(alignment: .bottom) {
            if savedBanner.isShowing {
                HStack(spacing: 8) {
                    Image(systemName: savedBanner.isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(AppColors.textOnAccent)
                    Text(savedBanner.message)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.textOnAccent)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(savedBanner.isSuccess ? AppColors.bannerSuccess : AppColors.bannerWarning)
                .clipShape(Capsule())
                .padding(.bottom, 60)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: savedBanner.isShowing)
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(onComplete: {
                showOnboarding = false
            })
            .environmentObject(store)
            .environmentObject(savedBanner)
            .environmentObject(reminderService)
            .environmentObject(healthKitService)
        }
    }
}

#Preview {
    ContentView()
}
