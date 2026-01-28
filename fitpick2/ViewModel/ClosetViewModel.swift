//
//  ClosetViewModel.swift
//  fitpick2
//
//  Created by Bryan Gavino on 1/21/26.
//

import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import FirebaseAILogic

class ClosetViewModel: ObservableObject {
    @Published var clothingItems: [ClothingItem] = []
    @Published var isUploading = false
    @Published var userGender: String = "Male"
    private let ai = FirebaseAI.firebaseAI(backend: .googleAI())
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var listener: ListenerRegistration?
    
    // Initialize Gemini 1.5 Flash
    private lazy var visionModel = ai.generativeModel(modelName: "gemini-2.5-flash")

    init() {
            startFirestoreListener()
        }
        
        // MARK: - Real-time Data Listener
        func startFirestoreListener() {
            guard let userEmail = Auth.auth().currentUser?.email else { return }
            
            // LOGIC: Query the 'clothes' collection for items belonging to this user
            listener = db.collection("clothes")
                .whereField("ownerEmail", isEqualTo: userEmail) // Filter by owner
                .order(by: "createdat", descending: true)      // Sort by new lowercase field
                .addSnapshotListener { [weak self] querySnapshot, error in
                    guard let documents = querySnapshot?.documents else {
                        print("Error fetching documents: \(error?.localizedDescription ?? "Unknown error")")
                        return
                    }
                    
                    self?.clothingItems = documents.compactMap { doc -> ClothingItem? in
                        let data = doc.data()
                        
                        let urlString = data["imageURL"] as? String ?? ""
                        let categoryString = data["category"] as? String ?? "Top"
                        let subCategory = data["subcategory"] as? String ?? "Other" // "subcategory"
                        
                        let category = ClothingCategory(rawValue: categoryString) ?? .top
                        
                        return ClothingItem(
                            id: UUID(uuidString: doc.documentID) ?? UUID(),
                            image: Image(systemName: "photo"),
                            uiImage: nil,
                            category: category,
                            subCategory: subCategory,
                            remoteURL: urlString
                        )
                    }
                }
        }

        // MARK: - Upload & AI Workflow
        func uploadAndCategorize(uiImage: UIImage) async {
            await MainActor.run { isUploading = true }
            
            guard let imageData = uiImage.jpegData(compressionQuality: 0.8),
                  let userEmail = Auth.auth().currentUser?.email else { return }
            
            let fileName = "\(UUID().uuidString).jpg"
            let storageRef = storage.reference().child("closet/\(fileName)")

            do {
                // 1. Upload Image
                _ = try await storageRef.putDataAsync(imageData)
                let downloadURL = try await storageRef.downloadURL()

                // 2. AI Analysis
                let prompt = """
                You are a personal stylist AI. Analyze this clothing image for a \(userGender).
                1. Main Category: Must be exactly one of "Top", "Bottom", or "Shoes".
                2. Sub-Category: Identify the specific item (e.g. "Bomber Jacket", "Pleated Skirt", "Loafers").
                Return valid JSON only: {"category": "...", "subcategory": "..."}
                """
                
                let response = try await visionModel.generateContent(prompt, uiImage)
                
                if let text = response.text,
                   let data = text.data(using: .utf8) {
                    
                    let result = try JSONDecoder().decode(AICategorization.self, from: data)
                    
                    // 3. Save to Firestore
                    // LOGIC: This automatically creates the "clothes" collection if it's missing.
//                    try await db.collection("clothes").addDocument(data: [
//                        "imageURL": downloadURL.absoluteString,
//                        "category": result.category,
//                        "subcategory": result.subcategory, // Lowercase
//                        "createdat": Timestamp(),          // Lowercase
//                        "ownerEmail": userEmail            // Required to filter items later
//                    ])
                    
                    try await db.collection("clothes").document("random").setData([
                        "imageURL": downloadURL.absoluteString,
                        "category": result.category,
                        "subcategory": result.subcategory, // Lowercase
                        "createdat": Timestamp(),          // Lowercase
                        "ownerEmail": userEmail            // Required to filter items later
                    ])
                }
            } catch {
                print("AI/Upload Error: \(error.localizedDescription)")
            }
            
            await MainActor.run { isUploading = false }
        }
        
        struct AICategorization: Codable {
            let category: String
            let subcategory: String
        }
        
        func fetchUserGender() {
            guard let userEmail = Auth.auth().currentUser?.email else { return }
            db.collection("users").document(userEmail).getDocument { [weak self] doc, _ in
                if let gender = doc?.get("gender") as? String {
                    DispatchQueue.main.async { self?.userGender = gender }
                }
            }
        }
        
        func deleteItem(_ item: ClothingItem) {
            // Delete directly from the flat 'clothes' collection
            db.collection("clothes").document(item.id.uuidString).delete()
        }

        deinit {
            listener?.remove()
        }
    }
