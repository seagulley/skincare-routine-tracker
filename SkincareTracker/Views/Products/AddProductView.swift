//
//  AddProductView.swift
//  SkincareTracker
//

import SwiftUI

struct AddProductView: View {
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
                    TextField("Comma-separated ingredients (e.g. Niacinamide, Hyaluronic Acid)", text: $ingredientsText, axis: .vertical)
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
            .navigationTitle("Add Product")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProduct()
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

    private func saveProduct() {
        if let nameError = InputSanitizer.validateProductName(name) {
            ingredientErrorMessage = nameError
            return
        }

        switch INCIIngredients.parseValidated(ingredientsText) {
        case .success(let ingredients):
            let product = Product(
                name: name,
                ingredients: ingredients,
                categoryId: selectedCategoryId
            )
            store.addProduct(product)
            savedBanner.show()
            dismiss()
        case .failure(let error):
            ingredientErrorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AddProductView()
        .environmentObject(AppStore())
        .environmentObject(SavedBannerTrigger())
}
