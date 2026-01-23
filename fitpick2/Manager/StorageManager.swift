//
//  StorageManager.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 1/21/26.
//

import SwiftUI
import FirebaseStorage

class StorageManager: ObservableObject {
    let storage = Storage.storage()
    
    func upload(username: String, selfie: UIImage, completion: @escaping(String) -> Void) {
        let storageRef = storage.reference().child("\(username)/selfie.jpg")
        
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
}
