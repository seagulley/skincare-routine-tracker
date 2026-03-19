//
//  ContentView.swift
//  SkincareTracker
//

import SwiftUI

enum AppTab: Int {
    case today, cycle, products, reminders
}

struct ContentView: View {
    @StateObject private var store = AppStore()
    @StateObject private var savedBanner = SavedBannerTrigger()
    @StateObject private var reminderService = ReminderService()
    @StateObject private var healthKitService = HealthKitService()
    @State private var showOnboarding = !OnboardingView.hasCompletedOnboarding
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(AppTab.today)

            CycleView()
                .tabItem { Label("Cycle", systemImage: "arrow.2.circlepath") }
                .tag(AppTab.cycle)

            ProductsView()
                .tabItem { Label("Products", systemImage: "drop.fill") }
                .tag(AppTab.products)

            RemindersView()
                .tabItem { Label("Reminders", systemImage: "bell.fill") }
                .tag(AppTab.reminders)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openTodayTab)) { _ in
            selectedTab = .today
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCycleTab)) { _ in
            selectedTab = .cycle
        }
        .onAppear {
            if UserDefaults.standard.bool(forKey: openCycleTabKey) {
                UserDefaults.standard.removeObject(forKey: openCycleTabKey)
                selectedTab = .cycle
            } else if UserDefaults.standard.bool(forKey: openTodayTabKey) {
                UserDefaults.standard.removeObject(forKey: openTodayTabKey)
                selectedTab = .today
            }
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
