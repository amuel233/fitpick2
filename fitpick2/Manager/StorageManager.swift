//
//  StorageManager.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 1/21/26.
//

import SwiftUI
import FirebaseStorage

class StorageManager: ObservableObject {
    private let storage = Storage.storage().reference()
    
    func uploadSelfie(email: String, selfie: UIImage, completion: @escaping(String) -> Void) {
        let storageRef = storage.child("users/\(email)/selfie.jpg")
        
        let data = selfie.jpegData(compressionQuality: 0.2)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpg"
        
        // Upload the image
        if let data = data {
            storageRef.putData(data, metadata: metadata) { (metadata, error) in
                if let error = error {
                    print("Error while uploading file: ", error)
                }
                
                if let metadata = metadata {
                    print("Metadata: ", metadata)
                    
                    storageRef.downloadURL { url, error in
                                    guard let imageURL = url?.absoluteString else {return}
                                    completion(imageURL)
                                }
                }
            }
        }
    }
    
    func uploadSocial(email: String, ootd: UIImage, completion: @escaping (String) -> Void) {
            // Convert image to data
            guard let imageData = ootd.jpegData(compressionQuality: 0.5) else { return }
            
            // Create a unique path for the post image
            let path = "socials/\(email)_\(UUID().uuidString).jpg"
            let fileRef = storage.child(path)
            
            // Upload the data
            fileRef.putData(imageData, metadata: nil) { metadata, error in
                if let error = error {
                    print("Upload error: \(error.localizedDescription)")
                    return
                }
                
                // Fetch the URL to save in Firestore
                fileRef.downloadURL { url, error in
                    if let urlString = url?.absoluteString {
                        completion(urlString)
                    }
                }
            }
        }
}
