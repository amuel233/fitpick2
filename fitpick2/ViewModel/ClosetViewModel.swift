//
//  ClosetViewModel.swift
//  fitpick2
//
//  Created by Bryan Gavino on 1/21/26.
//

import SwiftUI
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

class ClosetViewModel: ObservableObject {
    @Published var clothingItems: [ClothingItem] = []
    @Published var isUploading = false
    @Published var userGender: String = "Male" // Default
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    func fetchUserGender() {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        
        let userRef = db.collection("users").document(userEmail)
        userRef.getDocument { [weak self] (document, error) in
            if let document = document, document.exists {
                // Read the "gender" field specifically
                if let fetchedGender = document.get("gender") as? String {
                    DispatchQueue.main.async {
                        self?.userGender = fetchedGender
                    }
                }
            }
        }
    }

    func uploadClothing(uiImage: UIImage, category: ClothingCategory, subCategory: String) {
        guard let imageData = uiImage.jpegData(compressionQuality: 0.7) else { return }
        isUploading = true
        
        let fileName = "\(UUID().uuidString).jpg"
        let storageRef = storage.reference().child("closet/\(fileName)")
        
        storageRef.putData(imageData, metadata: nil) { [weak self] _, error in
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
            "subCategory": subCategory,
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
