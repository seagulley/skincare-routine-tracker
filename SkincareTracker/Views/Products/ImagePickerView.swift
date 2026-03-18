//
//  ImagePickerView.swift
//  SkincareTracker
//
//  Presents camera or photo library for scanning ingredient labels.
//

import SwiftUI
import UIKit

/// Identifiable wrapper for image picker source, used with fullScreenCover(item:).
struct ImagePickerSource: Identifiable {
    let id = UUID()
    let sourceType: ImagePickerView.SourceType
}

/// Wrapper for UIImagePickerController. Use for camera or photo library selection.
struct ImagePickerView: UIViewControllerRepresentable {
    enum SourceType {
        case camera
        case photoLibrary

        var uiKitSourceType: UIImagePickerController.SourceType {
            switch self {
            case .camera: return .camera
            case .photoLibrary: return .photoLibrary
            }
        }
    }

    let sourceType: SourceType
    let onImagePicked: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType.uiKitSourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImagePicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImagePicked = onImagePicked
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            } else {
                onCancel()
            }
            // Rely on binding update to dismiss fullScreenCover; avoid picker.dismiss to prevent cascade.
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
            // Do not call picker.dismiss — SwiftUI dismisses fullScreenCover when imagePickerSource becomes nil.
            // Calling picker.dismiss can cascade and dismiss the parent Add Product sheet.
        }
    }
}
