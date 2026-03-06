//
//  PutOffSheetView.swift
//  SkincareTracker
//

import SwiftUI

struct PutOffSheetView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    
    let item: ScheduleItem
    let routineType: RoutineType
    let onDismiss: () -> Void
    
    @State private var showUpdateFrequency = false
    @State private var newFrequencyDays: Int = 1
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                
                Text("Put off \(item.productName)?")
                    .font(.title2)
                    .multilineTextAlignment(.center)
                
                Text("The schedule will adjust. Would you like to update how often you use this product?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 16) {
                    Button {
                        showUpdateFrequency = true
                    } label: {
                        Text("Yes, update frequency")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button {
                        store.putOff(item, routineType: routineType)
                        onDismiss()
                        dismiss()
                    } label: {
                        Text("No, just put off")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .padding(.top, 32)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showUpdateFrequency) {
                UpdateFrequencySheetView(
                    productId: item.productId,
                    currentFrequency: item.product?.frequencyDays ?? 1,
                    onSave: { newDays in
                        store.putOff(item, routineType: routineType, newFrequency: newDays)
                        showUpdateFrequency = false
                        onDismiss()
                        dismiss()
                    },
                    onSkip: {
                        store.putOff(item, routineType: routineType)
                        showUpdateFrequency = false
                        onDismiss()
                        dismiss()
                    }
                )
            }
        }
    }
}

struct UpdateFrequencySheetView: View {
    let productId: UUID
    let currentFrequency: Int
    let onSave: (Int) -> Void
    let onSkip: () -> Void
    
    @State private var useEveryDays: Int
    @Environment(\.dismiss) private var dismiss
    
    init(productId: UUID, currentFrequency: Int, onSave: @escaping (Int) -> Void, onSkip: @escaping () -> Void) {
        self.productId = productId
        self.currentFrequency = currentFrequency
        self.onSave = onSave
        self.onSkip = onSkip
        self._useEveryDays = State(initialValue: currentFrequency)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Use every \(useEveryDays) day(s)", value: $useEveryDays, in: 1...30)
                    Text("Currently: every \(currentFrequency) day(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("New Frequency")
                } footer: {
                    Text("How often would you like to use this product going forward?")
                }
            }
            .navigationTitle("Update Frequency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        onSkip()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(useEveryDays)
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
            product: Product(name: "Vitamin C Serum", ingredients: [], frequencyDays: 1),
            date: Date(),
            routineType: .morning,
            order: 0,
            shouldApply: true
        ),
        routineType: .morning,
        onDismiss: {}
    )
    .environmentObject(AppStore())
}
