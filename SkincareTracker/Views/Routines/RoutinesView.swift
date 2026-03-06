//
//  RoutinesView.swift
//  SkincareTracker
//

import SwiftUI

struct RoutinesView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        NavigationStack {
            List {
                Section("Morning Routine") {
                    ForEach(store.morningRoutine.productIds, id: \.self) { productId in
                        if let product = store.product(by: productId) {
                            HStack {
                                Text(product.name)
                                Spacer()
                                Text(product.frequencyDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    NavigationLink {
                        EditRoutineView(routineType: .morning)
                    } label: {
                        Label("Edit Morning Routine", systemImage: "pencil")
                    }
                }
                
                Section("Night Routine") {
                    ForEach(store.nightRoutine.productIds, id: \.self) { productId in
                        if let product = store.product(by: productId) {
                            HStack {
                                Text(product.name)
                                Spacer()
                                Text(product.frequencyDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    NavigationLink {
                        EditRoutineView(routineType: .night)
                    } label: {
                        Label("Edit Night Routine", systemImage: "pencil")
                    }
                }
            }
            .navigationTitle("Routines")
        }
    }
}

#Preview {
    RoutinesView()
        .environmentObject(AppStore())
}
