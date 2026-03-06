//
//  ScheduleView.swift
//  SkincareTracker
//

import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var store: AppStore
    
    private var groupedByDate: [(date: Date, items: [ScheduleItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: store.scheduleItems.filter { $0.shouldApply }) { item in
            calendar.startOfDay(for: item.date)
        }
        return grouped
            .map { (date: $0.key, items: $0.value.sorted { $0.order < $1.order }) }
            .sorted { $0.date < $1.date }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedByDate, id: \.date) { group in
                    Section {
                        ForEach(group.items) { item in
                            ScheduleRowView(item: item)
                        }
                    } header: {
                        Text(formatDate(group.date))
                            .font(.headline)
                    }
                }
            }
            .navigationTitle("Schedule")
            .overlay {
                if store.scheduleItems.isEmpty {
                    ContentUnavailableView(
                        "No Schedule Yet",
                        systemImage: "calendar.badge.clock",
                        description: Text("Add products and set up your morning/night routines to see your schedule.")
                    )
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}

struct ScheduleRowView: View {
    let item: ScheduleItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.productName)
                    .font(.headline)
                Text(item.routineType.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let product = item.product {
                Text(product.frequencyDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ScheduleView()
        .environmentObject(AppStore())
}
