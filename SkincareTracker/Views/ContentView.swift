//
//  ContentView.swift
//  SkincareTracker
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = AppStore()
    
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
            
            ProductsView()
                .tabItem { Label("Products", systemImage: "drop.fill") }
            
            RoutinesView()
                .tabItem { Label("Routines", systemImage: "list.number") }
            
            ScheduleView()
                .tabItem { Label("Schedule", systemImage: "calendar") }
            
            RemindersView()
                .tabItem { Label("Reminders", systemImage: "bell.fill") }
        }
        .environmentObject(store)
    }
}

#Preview {
    ContentView()
}
