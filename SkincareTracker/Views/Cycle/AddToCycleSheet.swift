//
//  AddToCycleSheet.swift
//  SkincareTracker
//
//  Add a product to the cycle: search existing products or create new.
//

import SwiftUI

struct AddToCycleSheet: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var savedBanner: SavedBannerTrigger
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var showCreateProduct = false

    private var filteredProducts: [Product] {
        let notInCycle = store.productsNotInCycle
        guard !searchText.isEmpty else { return notInCycle }
        let q = searchText.lowercased()
        return notInCycle.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(filteredProducts) { product in
                        Button {
                            store.addProductToCycle(product)
                            savedBanner.show()
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Text(product.name)
                                    .foregroundStyle(AppColors.textPrimary)
                                if !product.ingredients.isEmpty {
                                    Text("\(product.ingredients.count) ingredients")
                                        .font(.caption)
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                            }
                        }
                        .listRowBackground(AppColors.rowBackground)
                    }
                } header: {
                    if store.productsNotInCycle.isEmpty {
                        Text("No products in collection")
                    } else {
                        Text("Products in collection")
                    }
                }

                Section {
                    Button {
                        showCreateProduct = true
                    } label: {
                        Label("Create new product", systemImage: "plus.circle.fill")
                            .foregroundStyle(AppColors.accent)
                    }
                    .listRowBackground(AppColors.rowBackground)
                }
            }
            .searchable(text: $searchText, prompt: "Search products")
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("Add to Cycle")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showCreateProduct) {
                CreateProductAndAddToCycleSheet(
                    onCreated: {
                        savedBanner.show()
                        dismiss()
                    },
                    onCancel: { showCreateProduct = false }
                )
                .environmentObject(store)
                .environmentObject(savedBanner)
            }
        }
    }
}

/// Minimal Add Product flow; on save, adds the product to the cycle and calls onCreated.
private struct CreateProductAndAddToCycleSheet: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var savedBanner: SavedBannerTrigger
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var ingredientsText = ""
    @State private var selectedCategoryId: String = "other"
    @State private var showScanSourcePicker = false
    @State private var imagePickerSource: ImagePickerSource?
    @State private var isScanning = false
    @State private var ingredientErrorMessage: String?

    let onCreated: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    TextField("Product name", text: $name)
                        .foregroundStyle(AppColors.textPrimary)
                        .listRowBackground(AppColors.rowBackground)
                    Picker("Category", selection: $selectedCategoryId) {
                        ForEach(ProductCategory.forPicker) { category in
                            Text(category.name).tag(category.id)
                        }
                    }
                    .foregroundStyle(AppColors.textPrimary)
                    .listRowBackground(AppColors.rowBackground)
                }

                Section("Ingredients") {
                    TextField("Comma-separated ingredients (optional)", text: $ingredientsText, axis: .vertical)
                        .lineLimit(2...4)
                        .foregroundStyle(AppColors.textPrimary)
                        .listRowBackground(AppColors.rowBackground)
                    Button {
                        showScanSourcePicker = true
                    } label: {
                        Label("Scan label", systemImage: "camera.viewfinder")
                            .foregroundStyle(AppColors.accent)
                    }
                    .listRowBackground(AppColors.rowBackground)
                }
            }
            .confirmationDialog("Scan ingredients", isPresented: $showScanSourcePicker) {
                Button("Take Photo") {
                    imagePickerSource = ImagePickerSource(sourceType: .camera)
                }
                Button("Choose from Library") {
                    imagePickerSource = ImagePickerSource(sourceType: .photoLibrary)
                }
                Button("Cancel", role: .cancel) {
                    imagePickerSource = nil
                }
            } message: {
                Text("Capture or select a photo of the ingredient list on your product label.")
            }
            .fullScreenCover(item: $imagePickerSource) { source in
                ImagePickerView(sourceType: source.sourceType, onImagePicked: { image in
                    imagePickerSource = nil
                    Task { await scanImage(image) }
                }, onCancel: {
                    imagePickerSource = nil
                })
            }
            .overlay {
                if isScanning {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    ProgressView("Scanning…")
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.2)
                }
            }
            .alert("Invalid Input", isPresented: Binding(
                get: { ingredientErrorMessage != nil },
                set: { if !$0 { ingredientErrorMessage = nil } }
            )) {
                Button("OK") { ingredientErrorMessage = nil }
            } message: {
                if let msg = ingredientErrorMessage {
                    Text(msg)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("New Product")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saveAndAddToCycle()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func scanImage(_ image: UIImage) async {
        isScanning = true
        defer { isScanning = false }
        guard let text = await IngredientLabelScanner.extractText(from: image) else { return }
        let normalized = INCIIngredients.normalizeForParsing(text)
        await MainActor.run {
            if ingredientsText.isEmpty {
                ingredientsText = normalized
            } else {
                ingredientsText += ", " + normalized
            }
        }
    }

    private func saveAndAddToCycle() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if let nameError = InputSanitizer.validateProductName(trimmedName) {
            ingredientErrorMessage = nameError
            return
        }

        switch INCIIngredients.parseValidated(ingredientsText) {
        case .success(let ingredients):
            let product = Product(
                name: name.trimmingCharacters(in: .whitespaces),
                ingredients: ingredients,
                categoryId: selectedCategoryId
            )
            store.addProduct(product)
            store.addProductToCycle(product)
            onCreated()
            dismiss()
        case .failure(let error):
            ingredientErrorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AddToCycleSheet()
        .environmentObject(AppStore())
        .environmentObject(SavedBannerTrigger())
}
