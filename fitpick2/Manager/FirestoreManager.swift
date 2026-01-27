//
//  FirestoreManager.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 1/15/26.
//

import FirebaseFirestore

class FirestoreManager: ObservableObject {
    private var db = Firestore.firestore()
    @Published var users = [User]()
    
    // Create
    func addUser(documentID: String, email: String, selfie: String) {
        
        let newUser = [
            "email":email,
            "selfie":selfie,
        ]
        
        db.collection("users").document(documentID).setData(newUser) { error in
               if let error = error {
                   print("Error creating document: \(error)")
               } else {
                   print("Document with custom ID: \(documentID) successfully created")
               }
           }
    }

    // Fetch today's hero outfit image name or url from `recommendations/today`
    func fetchHeroImageName(completion: @escaping (String?) -> Void) {
        let docRef = db.collection("recommendations").document("today")
        docRef.getDocument { snapshot, error in
            if let data = snapshot?.data(), let imageName = data["imageName"] as? String {
                completion(imageName)
            } else {
                completion(nil)
            }
        }
    }

    // Fetch wardrobe counts (e.g., shoes by subCategory) to help gap detection
    func fetchWardrobeCounts(completion: @escaping ([String: Int]) -> Void) {
        db.collection("clothes").getDocuments { snapshot, error in
            var counts: [String: Int] = [:]
            guard let docs = snapshot?.documents else {
                completion(counts)
                return
            }

            for doc in docs {
                let data = doc.data()
                let category = data["category"] as? String ?? ""
                let subCategory = data["subCategory"] as? String ?? ""

                if category == "Shoes" {
                    counts[subCategory, default: 0] += 1
                }
            }
            completion(counts)
        }
    }
    
    func fetchUserMeasurements(email: String, completion: @escaping ([String: Double]?) -> Void) {
            let db = Firestore.firestore()
            
            db.collection("users").document(email).getDocument { document, error in
                if let document = document, document.exists {
                    // Get the 'measurements' map from the document
                    let data = document.data()
                    let measurements = data?["measurements"] as? [String: Any]
                    print(measurements ?? "")
                    
                    // Convert [String: Any] to [String: Double]
                    var result: [String: Double] = [:]
                    measurements?.forEach { key, value in
                        if let doubleValue = value as? Double {
                            result[key] = doubleValue
                        } else if let stringValue = value as? String, let doubleValue = Double(stringValue) {
                            result[key] = doubleValue
                        }
                    }
                    completion(result)
                } else {
                    print("Document does not exist")
                    completion(nil)
                }
            }
        }
    
    
    
}
