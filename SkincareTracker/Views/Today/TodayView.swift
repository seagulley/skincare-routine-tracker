//
//  TodayView.swift
//  SkincareTracker
//
//  Current week calendar, cycle day, and routine display for today.
//

import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var savedBanner: SavedBannerTrigger

    private let calendar = Calendar.current

    private var todayStart: Date {
        calendar.startOfDay(for: Date())
    }

    private var weekDates: [Date] {
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: todayStart)) ?? todayStart
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    private var morningProducts: [Product] {
        store.productsForDate(todayStart, routineType: .morning)
    }

    private var nightProducts: [Product] {
        store.productsForDate(todayStart, routineType: .night)
    }

    private var currentCycleDay: Int {
        store.cycleDayIndex(for: todayStart) + 1
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    weekCalendarSection
                    cycleDaySection
                    routineSection
                    emptyStateIfNeeded
                }
                .padding()
            }
            .background(AppColors.background)
            .navigationTitle("Today's Routine")
        }
    }

    private var weekCalendarSection: some View {
        VStack(spacing: 8) {
            Text(todayStart.formatted(.dateTime.month(.wide).year()))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
                    VStack(spacing: 4) {
                        Text(shortWeekday(for: date))
                            .font(.caption2)
                            .foregroundStyle(AppColors.textTertiary)
                        Text("\(calendar.component(.day, from: date))")
                            .font(.subheadline.weight(calendar.isDate(date, inSameDayAs: todayStart) ? .bold : .regular))
                            .foregroundStyle(calendar.isDate(date, inSameDayAs: todayStart) ? AppColors.textOnAccent : AppColors.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(calendar.isDate(date, inSameDayAs: todayStart) ? AppColors.accent : Color.clear)
                            .clipShape(Circle())
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func shortWeekday(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private var cycleDaySection: some View {
        VStack(spacing: 4) {
            Text("Day \(currentCycleDay)")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AppColors.accent)
            Text("of your \(store.cycleLength)-day cycle")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var routineSection: some View {
        VStack(spacing: 16) {
            routineCard(
                title: "Morning routine",
                icon: "sun.max.fill",
                products: morningProducts,
                iconGradient: [AppColors.morning, Color(red: 255/255, green: 235/255, blue: 150/255)]
            )

            routineCard(
                title: "Night routine",
                icon: "moon.fill",
                products: nightProducts,
                iconGradient: [AppColors.night, Color(red: 130/255, green: 170/255, blue: 230/255)]
            )
        }
    }

    private func routineCard(
        title: String,
        icon: String,
        products: [Product],
        iconGradient: [Color]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(AppColors.textOnDark)
                    .frame(width: 40, height: 40)
                    .background(
                        LinearGradient(
                            colors: iconGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())

                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
            }

            if products.isEmpty {
                Text("No products assigned for \(title.lowercased().replacingOccurrences(of: " routine", with: ""))")
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(AppColors.textTertiary)
            } else {
                ForEach(products) { product in
                    HStack(spacing: 12) {
                        if let color = store.productColor(for: product) {
                            Circle()
                                .fill(color)
                                .frame(width: 8, height: 8)
                        }
                        Text(product.name)
                            .font(.body)
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var emptyStateIfNeeded: some View {
        if morningProducts.isEmpty && nightProducts.isEmpty {
            VStack(spacing: 12) {
                Text("No routine for this day")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Text("Go to the Cycle tab to assign products")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(AppColors.accentLight)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    TodayView()
        .environmentObject(AppStore())
        .environmentObject(SavedBannerTrigger())
}
