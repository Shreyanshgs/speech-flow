//
//  VideoPicker.swift
//  SpeechFlow
//
//  Created by Shreyansh Singh on 5/21/25.
//

import PhotosUI
import SwiftUI

struct VideoPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let itemProvider = results.first?.itemProvider,
                  itemProvider.hasItemConformingToTypeIdentifier("public.movie") else { return }

            itemProvider.loadFileRepresentation(forTypeIdentifier: "public.movie") { url, error in
                guard let url = url else { return }

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
                try? FileManager.default.copyItem(at: url, to: tempURL)

                DispatchQueue.main.async {
                    self.onPick(tempURL)
                }
            }
        }
    }
}
