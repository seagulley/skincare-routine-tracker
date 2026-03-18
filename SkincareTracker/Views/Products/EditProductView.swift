//
//  EditProductView.swift
//  SkincareTracker
//

import SwiftUI

struct EditProductView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var savedBanner: SavedBannerTrigger
    @Environment(\.dismiss) private var dismiss
    let product: Product

    @State private var name: String
    @State private var ingredientsText: String
    @State private var selectedCategoryId: String
    @State private var showScanSourcePicker = false
    @State private var imagePickerSource: ImagePickerSource?
    @State private var isScanning = false
    @State private var ingredientErrorMessage: String?

    init(product: Product) {
        self.product = product
        _name = State(initialValue: product.name)
        _ingredientsText = State(initialValue: product.ingredients.map(\.name).joined(separator: ", "))
        _selectedCategoryId = State(initialValue: product.categoryId ?? "other")
    }

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
                    TextField("Comma-separated ingredients", text: $ingredientsText, axis: .vertical)
                        .lineLimit(3...6)
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
            .navigationTitle("Edit Product")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(name.isEmpty)
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

    private func saveChanges() {
        if let nameError = InputSanitizer.validateProductName(name) {
            ingredientErrorMessage = nameError
            return
        }

        switch INCIIngredients.parseValidated(ingredientsText) {
        case .success(let ingredients):
            store.updateProduct(productId: product.id, name: name, ingredients: ingredients, categoryId: selectedCategoryId)
            savedBanner.show()
            dismiss()
        case .failure(let error):
            ingredientErrorMessage = error.localizedDescription
        }
    }
}
