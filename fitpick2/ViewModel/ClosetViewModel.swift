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
    @Published var isGeneratingTryOn = false
    @Published var generatedTryOnImage: UIImage? = nil
    
    // Stores text messages if the AI refuses to generate an image
    @Published var tryOnMessage: String? = nil
    
    @Published var userGender: String = "Male"
    private var calendarObserver: NSObjectProtocol?
    
    private let ai = FirebaseAI.firebaseAI(backend: .googleAI())
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var listener: ListenerRegistration?
    
    private lazy var visionModel = ai.generativeModel(modelName: "gemini-2.5-flash")
    private lazy var imageGenModel = ai.generativeModel(modelName: "gemini-2.5-flash-image")
    
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
        
        listener = db.collection("clothes")
            .whereField("ownerEmail", isEqualTo: userEmail)
            .order(by: "createdat", descending: true)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let documents = querySnapshot?.documents else { return }
                
                self?.clothingItems = documents.compactMap { doc -> ClothingItem? in
                    let data = doc.data()
                    return ClothingItem(
                        id: doc.documentID,
                        image: Image(systemName: "photo"),
                        uiImage: nil,
                        category: ClothingCategory(rawValue: data["category"] as? String ?? "") ?? .top,
                        subCategory: data["subcategory"] as? String ?? "Other",
                        remoteURL: data["imageURL"] as? String ?? ""
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
            _ = try await storageRef.putDataAsync(imageData)
            let downloadURL = try await storageRef.downloadURL()
            
            let prompt = """
            You are a personal stylist AI. Analyze this clothing image for a \(userGender).
            1. Main Category: Must be exactly one of "Top", "Bottom", "Shoes", or "Accessories".
            2. Sub-Category: Identify the specific item (e.g. "Bomber Jacket", "Pleated Skirt", "Loafers").
            Return valid JSON only: {"category": "...", "subcategory": "..."}
            """
            
            let response = try await visionModel.generateContent(prompt, uiImage)
            
            if let text = response.text?.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines),
               let data = text.data(using: .utf8) {
                
                let result = try JSONDecoder().decode(AICategorization.self, from: data)
                let customDocID = "\(userEmail)_\(Int(Date().timeIntervalSince1970))"
                
                try await db.collection("clothes").document(customDocID).setData([
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
    
    // MARK: - Virtual Try-On Generation (UPDATED PROMPT)
    func generateVirtualTryOn(selectedItemIDs: Set<String>) async {
        print("DEBUG: Starting Try-On Process...")
        
        await MainActor.run {
            isGeneratingTryOn = true
            generatedTryOnImage = nil
            tryOnMessage = nil
        }
        
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        
        do {
            // 1. Fetch User Avatar
            let userDoc = try await db.collection("users").document(userEmail).getDocument()
            guard let avatarURLString = userDoc.data()?["avatarURL"] as? String,
                  let avatarURL = URL(string: avatarURLString) else {
                print("DEBUG: No avatar URL found.")
                await MainActor.run { isGeneratingTryOn = false }
                return
            }
            
            let (avatarData, _) = try await URLSession.shared.data(from: avatarURL)
            guard let avatarImage = UIImage(data: avatarData) else { return }
            
            // 2. Fetch Selected Clothes
            let selectedClothes = clothingItems.filter { selectedItemIDs.contains($0.id) }
            
            // Generate a descriptive list of items for the prompt (e.g., "T-Shirt, Jeans")
            let itemDescriptions = selectedClothes.map { $0.subCategory }.joined(separator: ", ")
            print("DEBUG: Generating look for items: \(itemDescriptions)")
            
            var clothingImages: [UIImage] = []
            for item in selectedClothes {
                if let url = URL(string: item.remoteURL) {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let img = UIImage(data: data) {
                        clothingImages.append(img)
                    }
                }
            }
            
            // 3. Construct Request with STRICTER Prompt
            let promptText = """
                        TASK: Edit Image 1 only. This is NOT a photorealistic generation task.
                        
                        STYLE CONSTRAINT:
                        - The output must remain to be the avatar with the selected clothes.
                        - Do NOT generate a photorealistic human.
                        - Preserve the same 3D art style, shading, materials, and rendering quality as Image 1.
                        
                        SOURCE IMAGES:
                        - Image 1 (Avatar): This is the base 3D avatar. The head, face, hair, skin tone, body shape, pose, proportions, and 3D rendering style must remain unchanged.
                        - Images 3+ (Clothing): These are garment design references only. Ignore any people shown.
                        
                        CRITICAL IDENTITY & STYLE LOCK:
                        - Do NOT regenerate, replace, or stylize the head or face.
                        - Do NOT change the avatar into a real person or realistic photograph.
                        - The avatar must clearly remain the same as Image 1.
                        
                        CLOTHING APPLICATION:
                        - Extract ONLY garment design, texture, cut, and color from clothing images.
                        - Apply garments onto the body of Image 1.
                        - Do NOT copy anatomy, skin, or pose from clothing images.
                        - ONLY replace clothing items explicitly selected.
                        - If a clothing category is not selected, leave it unchanged.
                        
                        COMPOSITION:
                        - Full-body framing with head and feet visible.
                        - Avatar centered in a neutral A-pose (arms slightly out, legs straight) and facing forward.
                        
                        OUTFIT REQUIREMENTS:
                        The avatar must wear: \(itemDescriptions)
                        
                        OUTPUT(STRICT):
                        A single uncropped full-body of Image 1, wearing the selected items.
                        """
            
            var parts: [any Part] = []
            parts.append(TextPart(promptText))
            
            if let avatarJPEG = avatarImage.jpegData(compressionQuality: 0.8) {
                parts.append(InlineDataPart(data: avatarJPEG, mimeType: "image/jpeg"))
            }
            
            for img in clothingImages {
                if let clothingJPEG = img.jpegData(compressionQuality: 0.8) {
                    parts.append(InlineDataPart(data: clothingJPEG, mimeType: "image/jpeg"))
                }
            }
            
            // 4. API Call
            let content = ModelContent(role: "user", parts: parts)
            let response = try await imageGenModel.generateContent([content])
            
            // 5. Handle Response
            if let firstCandidate = response.candidates.first,
               let firstPart = firstCandidate.content.parts.first {
                
                if let inlineData = firstPart as? InlineDataPart,
                   let generatedImage = UIImage(data: inlineData.data) {
                    
                    print("DEBUG: Image generated successfully.")
                    await MainActor.run {
                        self.generatedTryOnImage = generatedImage
                        self.isGeneratingTryOn = false
                    }
                    try await saveGeneratedImageToFirebase(image: generatedImage, itemIDs: Array(selectedItemIDs), userEmail: userEmail)
                    
                } else if let textPart = firstPart as? TextPart {
                    print("DEBUG: Model refused image generation. Reason: \(textPart.text)")
                    await MainActor.run {
                        self.tryOnMessage = "Stylist Note: \(textPart.text)"
                        self.isGeneratingTryOn = false
                    }
                }
            } else {
                print("DEBUG: Empty response.")
                await MainActor.run { isGeneratingTryOn = false }
            }
            
        } catch {
            print("DEBUG: Error - \(error.localizedDescription)")
            await MainActor.run { isGeneratingTryOn = false }
        }
    }
    
    private func saveGeneratedImageToFirebase(image: UIImage, itemIDs: [String], userEmail: String) async throws {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        let fileName = "generated_\(UUID().uuidString).jpg"
        let storageRef = storage.reference().child("generated_looks/\(fileName)")
        
        _ = try await storageRef.putDataAsync(imageData)
        let downloadURL = try await storageRef.downloadURL()
        
        let customDocID = "\(userEmail)_\(Int(Date().timeIntervalSince1970))"
        
        try await db.collection("generated_looks").document(customDocID).setData([
            "imageURL": downloadURL.absoluteString,
            "ownerEmail": userEmail,
            "itemsUsed": itemIDs,
            "createdat": FieldValue.serverTimestamp()
        ])
    }
    
    func fetchUserGender() {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        db.collection("users").document(userEmail).getDocument { [weak self] doc, _ in
            if let gender = doc?.get("gender") as? String {
                DispatchQueue.main.async { self?.userGender = gender }
            }
        }
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
    func deleteItem(_ item: ClothingItem) {
            // 1. Delete from Firestore
            db.collection("clothes").document(item.id).delete()
            
            // 2. Delete from Storage (Moved back here)
            if !item.remoteURL.isEmpty {
                storage.reference(forURL: item.remoteURL).delete { error in
                    if let error = error {
                        print("Error deleting storage image: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        /// Suggest clothing items for a given event string...
        // ... (suggestItems function remains the same) ...
        
        deinit {
            // Clean up listeners only
            listener?.remove()
            if let obs = calendarObserver {
                NotificationCenter.default.removeObserver(obs)
            }
        }
    }
