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

// MARK: - Helper Models
struct AICategorization: Codable {
    let category: String
    let subcategory: String
}

class ClosetViewModel: ObservableObject {
    @Published var clothingItems: [ClothingItem] = []
    @Published var isUploading = false
    @Published var userGender: String = "Male"
    private var calendarObserver: NSObjectProtocol?
    
    private let ai = FirebaseAI.firebaseAI(backend: .googleAI())
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var listener: ListenerRegistration?
    
    // Initialize Gemini 2.5 Flash
    private lazy var visionModel = ai.generativeModel(modelName: "gemini-2.5-flash")

    init() {
        startFirestoreListener()
        // Listen for calendar updates and auto-generate try-on suggestions
        calendarObserver = NotificationCenter.default.addObserver(forName: Notification.Name("CalendarDidUpdate"), object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            let event = note.userInfo?["event"] as? String
            let suggestions = self.suggestItems(for: event)
            let ids = suggestions.map { $0.id }
            NotificationCenter.default.post(name: Notification.Name("TryOnSuggestion"), object: nil, userInfo: ["ids": ids])
        }
    }
    
    // MARK: - Real-time Data Listener
    func startFirestoreListener() {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        
        // This query requires the index link from your previous error
        listener = db.collection("clothes")
            .whereField("ownerEmail", isEqualTo: userEmail)
            .order(by: "createdat", descending: true)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let documents = querySnapshot?.documents else {
                    print("Error fetching documents: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self?.clothingItems = documents.compactMap { doc -> ClothingItem? in
                    let data = doc.data()
                    
                    let urlString = data["imageURL"] as? String ?? ""
                    let categoryString = data["category"] as? String ?? "Top"
                    let subCategory = data["subcategory"] as? String ?? "Other"
                    let category = ClothingCategory(rawValue: categoryString) ?? .top
                    
                    return ClothingItem(
                        id: doc.documentID,
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
            // 1. Upload Image to Storage
            _ = try await storageRef.putDataAsync(imageData)
            let downloadURL = try await storageRef.downloadURL()

            // 2. AI Analysis
            let prompt = """
            You are a personal stylist AI. Analyze this clothing image for a \(userGender).
            1. Main Category: Must be exactly one of "Top", "Bottom", "Shoes", or "Accessories".
            2. Sub-Category: Identify the specific item (e.g. "Bomber Jacket", "Pleated Skirt", "Loafers").
            Return valid JSON only: {"category": "...", "subcategory": "..."}
            """
            
            let response = try await visionModel.generateContent(prompt, uiImage)
            
            // Extract and clean JSON string from AI response
            if let text = response.text?.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines),
               let data = text.data(using: .utf8) {
                
                let result = try JSONDecoder().decode(AICategorization.self, from: data)
                
                // 3. Save to Firestore
                try await db.collection("clothes").addDocument(data: [
                    "imageURL": downloadURL.absoluteString,
                    "category": result.category,
                    "subcategory": result.subcategory,
                    "createdat": FieldValue.serverTimestamp(),
                    "ownerEmail": userEmail
                ])
            }
        } catch {
            print("AI/Upload Error: \(error.localizedDescription)")
        }
        
        await MainActor.run { isUploading = false }
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
        db.collection("clothes").document(item.id).delete()
    }

    /// Suggest clothing items for a given event string using stored AI-generated `subCategory` and `category` metadata.
    /// Returns a prioritized list of suggestions (may be empty).
    func suggestItems(for event: String?) -> [ClothingItem] {
        let txt = (event ?? "").lowercased()
        if txt.isEmpty {
            // If no event context, return a few recent items
            return Array(clothingItems.prefix(3))
        }

        // Keyword mapping to categories/subcategories (simple heuristic)
        let mappings: [String: [String]] = [
            "formal": ["formal", "blazer", "suit", "dress", "heels", "loafers"],
            "workout": ["workout", "running", "gym", "sneaker", "trainer"],
            "casual": ["casual", "tee", "jeans", "sneaker", "loafers"],
            "beach": ["swim", "bikini", "flip", "sandals"],
            "outdoor": ["jacket", "coat", "windbreaker", "boots"]
        ]

        // collect candidate items with score
        var scored: [(item: ClothingItem, score: Int)] = []

        for item in clothingItems {
            var score = 0
            let sub = item.subCategory.lowercased()
            let cat = item.category.rawValue.lowercased()

            // direct substring matches boost score
            if txt.contains(sub) || sub.contains(txt) { score += 4 }
            if txt.contains(cat) || cat.contains(txt) { score += 3 }

            // mapping-based matches
            for (_, keys) in mappings {
                for k in keys {
                    if txt.contains(k) && (sub.contains(k) || cat.contains(k) || item.subCategory.lowercased().contains(k)) {
                        score += 5
                    }
                }
            }

            if score > 0 {
                scored.append((item, score))
            }
        }

        // If we found scored items, sort by score and return top 5
        if !scored.isEmpty {
            let sorted = scored.sorted { $0.score > $1.score }.map { $0.item }
            return Array(sorted.prefix(5))
        }

        // Fallback: return a few recent items
        return Array(clothingItems.prefix(3))
    }

    deinit {
        listener?.remove()
        if let obs = calendarObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }
}
