//
//  PutOffSheetView.swift
//  SkincareTracker
//

import SwiftUI

struct PutOffSheetView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var savedBanner: SavedBannerTrigger
    @Environment(\.dismiss) private var dismiss
    
    let item: ScheduleItem
    let routineType: RoutineType
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 48))
                    .foregroundStyle(AppColors.textSecondary)
                
                Text("Put off \(item.productName)?")
                    .font(.title2)
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("This product will be hidden from today's routine.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button {
                    store.putOff(item, routineType: routineType)
                    savedBanner.show()
                    onDismiss()
                    dismiss()
                } label: {
                    Text("Put off")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.primaryAction)
                        .foregroundStyle(AppColors.textOnAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .padding(.top, 32)
            .background(AppColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    PutOffSheetView(
        item: ScheduleItem(
            productId: UUID(),
            productName: "Vitamin C Serum",
            product: Product(name: "Vitamin C Serum", ingredients: []),
            date: Date(),
            routineType: .morning,
            order: 0,
            shouldApply: true
        ),
        routineType: .morning,
        onDismiss: {}
    )
    .environmentObject(AppStore())
    .environmentObject(SavedBannerTrigger())
}
