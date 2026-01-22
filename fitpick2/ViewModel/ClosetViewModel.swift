//
//  ClosetViewModel.swift
//  fitpick2
//
//  Created by Bryan Gavino on 1/21/26.
//

import SwiftUI
import FirebaseStorage
import FirebaseFirestore

class ClosetViewModel: ObservableObject {
    @Published var clothingItems: [ClothingItem] = []
    @Published var isUploading = false
    @Published var userGender: String = "Male" // Default gender, should be set from BodyMeasurementView
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    func uploadClothing(uiImage: UIImage, category: ClothingCategory, subCategory: String) {
        guard let imageData = uiImage.jpegData(compressionQuality: 0.7) else { return }
        isUploading = true
        
        let fileName = "\(UUID().uuidString).jpg"
        let storageRef = storage.reference().child("closet/\(fileName)")
        
        storageRef.putData(imageData, metadata: nil) { [weak self] _, error in
            if let error = error {
                print("Upload error: \(error.localizedDescription)")
                DispatchQueue.main.async { self?.isUploading = false }
                return
            }
            
            storageRef.downloadURL { url, _ in
                guard let downloadURL = url else { return }
                self?.saveToFirestore(url: downloadURL.absoluteString, category: category, subCategory: subCategory, image: uiImage)
            }
        }
    }
    
    private func saveToFirestore(url: String, category: ClothingCategory, subCategory: String, image: UIImage) {
        db.collection("clothes").addDocument(data: [
            "imageURL": url,
            "category": category.rawValue,
            "subCategory": subCategory, // Save sub-category to Firestore
            "createdAt": Timestamp()
        ]) { [weak self] error in
            DispatchQueue.main.async {
                if error == nil {
                    let newItem = ClothingItem(
                        image: Image(uiImage: image),
                        uiImage: image,
                        category: category,
                        subCategory: subCategory,
                        remoteURL: url
                    )
                    self?.clothingItems.append(newItem)
                }
                self?.isUploading = false
            }
        }
    }
    
    func deleteItem(_ item: ClothingItem) {
        clothingItems.removeAll { $0.id == item.id }
    }
}
