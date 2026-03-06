//
//  TodayView.swift
//  SkincareTracker
//

import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: AppStore
    @State private var showPutOffPrompt: PutOffPromptItem?
    
    var body: some View {
        NavigationStack {
            List {
                Section("Morning") {
                    ForEach(store.todayMorningItems) { item in
                        TodayProductRow(
                            item: item,
                            onPutOff: {
                                showPutOffPrompt = PutOffPromptItem(
                                    scheduleItem: item,
                                    routineType: .morning
                                )
                            }
                        )
                    }
                }
                
                Section("Night") {
                    ForEach(store.todayNightItems) { item in
                        TodayProductRow(
                            item: item,
                            onPutOff: {
                                showPutOffPrompt = PutOffPromptItem(
                                    scheduleItem: item,
                                    routineType: .night
                                )
                            }
                        )
                    }
                }
            }
            .navigationTitle("Today")
            .overlay {
                if store.todayMorningItems.isEmpty && store.todayNightItems.isEmpty {
                    ContentUnavailableView(
                        "Nothing Scheduled Today",
                        systemImage: "sun.max",
                        description: Text("Add products and set up your routines to see today's skincare schedule.")
                    )
                }
            }
            .sheet(item: $showPutOffPrompt) { prompt in
                PutOffSheetView(
                    item: prompt.scheduleItem,
                    routineType: prompt.routineType,
                    onDismiss: { showPutOffPrompt = nil }
                )
                .environmentObject(store)
            }
        }
    }
}

struct PutOffPromptItem: Identifiable {
    let id = UUID()
    let scheduleItem: ScheduleItem
    let routineType: RoutineType
}

struct TodayProductRow: View {
    let item: ScheduleItem
    let onPutOff: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.productName)
                    .font(.headline)
                if let product = item.product {
                    Text(product.frequencyDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                onPutOff()
            } label: {
                Text("Put Off")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TodayView()
        .environmentObject(AppStore())
}
