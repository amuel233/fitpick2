//
//  ClosetViewModel.swift
//  fitpick
//
//  Created by Bryan Gavino on 1/21/26.
//

import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import FirebaseAILogic

class ClosetViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var clothingItems: [ClothingItem] = []
    
    // UI States
    @Published var isUploading = false
    @Published var isGeneratingTryOn = false
    @Published var isSavingTryOn = false
    @Published var tryOnSavedSuccess = false
    
    // Try-On Data
    @Published var generatedTryOnImage: UIImage? = nil
    @Published var tryOnMessage: String? = nil
    
    // USER PROFILE DATA
    @Published var userGender: String = "Male" // Default, updated on fetch
    
    // Internal Tracker for Saving
    private var currentItemsUsed: [String] = []
    
    // Firebase Services
    private let ai = FirebaseAI.firebaseAI(backend: .googleAI())
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var listener: ListenerRegistration?
    
    // AI Models
    private lazy var visionModel = ai.generativeModel(modelName: "gemini-2.5-flash")
    private lazy var imageGenModel = ai.generativeModel(modelName: "gemini-2.5-flash-image")

    init() {
        startFirestoreListener()
        fetchUserGender() // Ensure we have gender loaded
    }
    
    // MARK: - 1. Real-time Data Listener
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
                        remoteURL: data["imageURL"] as? String ?? "",
                        size: data["size"] as? String ?? "Unknown"
                    )
                }
            }
    }

    // MARK: - 2. Gallery Upload (Standard AI Categorization)
    func uploadAndCategorize(uiImage: UIImage) async {
        await MainActor.run { isUploading = true }
        
        guard let optimizedImage = resizeImage(image: uiImage, targetSize: CGSize(width: 1024, height: 1024)),
              let imageData = optimizedImage.jpegData(compressionQuality: 0.6),
              let userEmail = Auth.auth().currentUser?.email else { return }
        
        let fileName = "\(UUID().uuidString).jpg"
        let storageRef = storage.reference().child("closet/\(fileName)")

        do {
            _ = try await storageRef.putDataAsync(imageData)
            let downloadURL = try await storageRef.downloadURL()

            // Added Gender context to this prompt as well for better accuracy
            let prompt = """
            You are a personal stylist AI. Analyze this clothing image for a \(userGender) user.
            1. Main Category: "Top", "Bottom", "Shoes", or "Accessories".
            2. Sub-Category: Specific type (e.g. "Bomber Jacket", "Maxi Skirt").
            3. Size: Read the tag if visible. If not, return "One Size" or "Unknown".
            Return valid JSON only: {"category": "...", "subcategory": "...", "size": "..."}
            """
            
            let response = try await visionModel.generateContent(prompt, optimizedImage)
            
            if let text = response.text?.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines),
               let data = text.data(using: .utf8) {
                
                // Decode assuming you have the AICategorization struct in your Models file
                // If not, use a simple Dictionary or local struct
                struct TempAICat: Codable { let category: String; let subcategory: String; let size: String }
                let result = try JSONDecoder().decode(TempAICat.self, from: data)
                
                saveToFirestore(
                    url: downloadURL.absoluteString,
                    category: result.category,
                    subCategory: result.subcategory,
                    size: result.size,
                    measurements: nil,
                    type: "Gallery_Manual"
                )
            }
        } catch {
            print("AI/Upload Error: \(error.localizedDescription)")
        }
        await MainActor.run { isUploading = false }
    }
    
    // MARK: - 3. LiDAR/Camera Upload (Smart Measurement)
    
    /// UPDATED: Determines the best size label dynamically based on Gender and Category
    func determineSizeFromAutoMeasurements(width: Double, length: Double, category: String, subCategory: String) async -> String {
        
        // 1. Contextualize the "Width" measurement based on the item type
        var widthContext = "Width"
        if category.lowercased().contains("bottom") {
             widthContext = "Flat Waist Width (across the top edge)"
        } else if category.lowercased().contains("top") {
             widthContext = userGender.lowercased() == "female" ? "Flat Bust Width (pit-to-pit)" : "Flat Chest Width (pit-to-pit)"
        } else if category.lowercased().contains("shoe") {
             widthContext = "Widest part of sole"
        }
        
        // 2. Build the Dynamic Prompt
        let prompt = """
        You are an expert tailor. I have a [\(userGender)] [\(subCategory)] (\(category)).
        The item was laid flat and measured using LiDAR:
        
        - \(widthContext): \(String(format: "%.1f", width)) inches.
        - Total Length: \(String(format: "%.1f", length)) inches.
        
        Task:
        1. Convert these flat measurements to body circumference if necessary (e.g., Waist Width * 2).
        2. Compare against standard [\(userGender)] sizing charts for [\(subCategory)].
        3. Determine the most likely US Size Label.
        
        Rules:
        - For Jeans/Pants: Return Waist x Length (e.g., "32x30") or Standard (e.g. "US 8").
        - For Tops: Return Standard (e.g. "S", "M", "L").
        - For Shoes: Return US Shoe Size (e.g. "US 9").
        
        Output:
        Return ONLY the estimated size label string. No explanation.
        """
        
        do {
            let response = try await ai.generativeModel(modelName: "gemini-2.5-flash").generateContent(prompt)
            return response.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
        } catch {
            return "Unknown"
        }
    }
    
    /// Saves an item with specific LiDAR measurements attached
    func saveAutoMeasuredItem(image: UIImage, category: String, subCategory: String, size: String, width: Double, length: Double) async {
        await MainActor.run { isUploading = true }
        
        guard let optimizedImage = resizeImage(image: image, targetSize: CGSize(width: 1024, height: 1024)),
              let imageData = optimizedImage.jpegData(compressionQuality: 0.6) else { return }
        
        let fileName = "\(UUID().uuidString).jpg"
        let storageRef = storage.reference().child("closet/\(fileName)")
        
        do {
            _ = try await storageRef.putDataAsync(imageData)
            let downloadURL = try await storageRef.downloadURL()
            
            saveToFirestore(
                url: downloadURL.absoluteString,
                category: category,
                subCategory: subCategory,
                size: size,
                measurements: ["auto_width": width, "auto_length": length],
                type: "LiDAR_Auto"
            )
            
        } catch {
            print("Upload Error: \(error.localizedDescription)")
        }
        await MainActor.run { isUploading = false }
    }
    
    // MARK: - 4. Manual Save (Fallback)
    func saveManualItem(image: UIImage, category: ClothingCategory, subCategory: String, size: String) async {
        await MainActor.run { isUploading = true }
        
        guard let optimizedImage = resizeImage(image: image, targetSize: CGSize(width: 1024, height: 1024)),
              let imageData = optimizedImage.jpegData(compressionQuality: 0.6) else { return }
        
        let fileName = "\(UUID().uuidString).jpg"
        let storageRef = storage.reference().child("closet/\(fileName)")

        do {
            _ = try await storageRef.putDataAsync(imageData)
            let downloadURL = try await storageRef.downloadURL()
            
            saveToFirestore(
                url: downloadURL.absoluteString,
                category: category.rawValue,
                subCategory: subCategory,
                size: size,
                measurements: nil,
                type: "Manual_Override"
            )
            
        } catch {
            print("Upload Error: \(error.localizedDescription)")
        }
        await MainActor.run { isUploading = false }
    }
    
    // Internal Helper
    private func saveToFirestore(url: String, category: String, subCategory: String, size: String, measurements: [String: Double]?, type: String) {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        let customDocID = "\(userEmail)_\(Int(Date().timeIntervalSince1970))"
        
        var data: [String: Any] = [
            "imageURL": url,
            "category": category,
            "subcategory": subCategory,
            "size": size,
            "createdat": FieldValue.serverTimestamp(),
            "ownerEmail": userEmail,
            "gender": userGender, // Save gender with item for future reference
            "uploadType": type
        ]
        
        if let meas = measurements {
            data["measurements"] = meas
        }
        
        db.collection("clothes").document(customDocID).setData(data)
    }

    // MARK: - 5. Virtual Try-On Logic (Measurement-Aware Mannequin)
        /// Generates a "Ghost Mannequin" visualization.
        /// - Strategy: Combines the Visual Reference (Avatar) with Quantitative Data (Measurements)
        ///   to generate a mannequin that matches the user's exact body proportions.
        func generateVirtualTryOn(selectedItemIDs: Set<String>) async {
            print("DEBUG: Starting Try-On (Measurement Match Mode)...")
            
            // 1. Reset UI State
            await MainActor.run {
                isGeneratingTryOn = true
                generatedTryOnImage = nil
                tryOnMessage = nil
                tryOnSavedSuccess = false
                currentItemsUsed = Array(selectedItemIDs)
            }
            
            // 2. Auth Check
            guard let currentUserEmail = Auth.auth().currentUser?.email else { return }
            
            do {
                // 3. Fetch User Profile & Measurements
                let userDoc = try await db.collection("users").document(currentUserEmail).getDocument()
                let userData = userDoc.data()
                
                // A. Get Avatar URL (Visual Reference)
                guard let avatarURLString = userData?["avatarURL"] as? String,
                      let avatarURL = URL(string: avatarURLString) else {
                    await MainActor.run {
                        isGeneratingTryOn = false
                        tryOnMessage = "Please generate an avatar first."
                    }
                    return
                }
                
                // B. Get Quantitative Measurements (Data Reference)
                var measurementString = "Standard Average Build"
                if let m = userData?["measurements"] as? [String: Any] {
                    let h = m["height"] as? Double ?? 0
                    let w = m["bodyWeight"] as? Double ?? 0
                    let chest = m["chest"] as? Double ?? 0
                    let waist = m["waist"] as? Double ?? 0
                    let hips = m["hips"] as? Double ?? 0
                    
                    // Format for Prompt: "Height: 180cm, Weight: 75kg, Chest: 100cm..."
                    measurementString = """
                    Height: \(h) cm
                    Weight: \(w) kg
                    Chest: \(chest) cm
                    Waist: \(waist) cm
                    Hips: \(hips) cm
                    """
                }
                
                // 4. Download & Prepare Base Avatar
                let (avatarData, _) = try await URLSession.shared.data(from: avatarURL)
                guard let rawAvatar = UIImage(data: avatarData) else { return }
                let baseAvatarImage = resizeImage(image: rawAvatar, targetSize: CGSize(width: 1024, height: 1024)) ?? rawAvatar

                // 5. Prepare Clothes
                let selectedClothes = clothingItems.filter { selectedItemIDs.contains($0.id) }
                
                // 6. Construct Prompt
                var promptParts: [any Part] = []
                
                // --- PART A: Visual Instructions (Text) ---
                promptParts.append(TextPart("""
                ROLE: Virtual Fashion Stylist.
                TASK: Generate a high-quality ghost mannequin visualization of an outfit.
                
                VISUAL REQUIREMENTS (STRICT):
                1. POSE: Front-facing, standing straight. Arms must be slightly raised/held away from the body (A-Pose) to show the fit clearly.
                
                2. BODY SHAPE & DIMENSIONS (CRITICAL):
                   - You must generate a mannequin that MATCHES the user's specific measurements below.
                   - IF Waist is close to Chest size, render a straighter torso.
                   - IF Hips are wider than Waist, render a curvy/wide pelvic structure.
                   - IF Height is tall vs Weight is low, render a slender/lanky frame.
                   
                   [USER MEASUREMENTS]:
                   \(measurementString)
                
                3. SKIN TONE: Sample the skin color from the REFERENCE IMAGE (Image 1). The mannequin must match this skin tone.
                
                4. SUBJECT: A mannequin with an abstract/neutral head (no realistic face), but with the USER'S SKIN TONE and BODY SHAPE.
                
                5. BACKGROUND: Pure White (#FFFFFF). Clean studio lighting.
                """))
                
                // --- PART B: Reference Image ---
                promptParts.append(TextPart("\n\nREFERENCE IMAGE (For Skin Tone & Visual Proportions):"))
                if let avatarJPG = baseAvatarImage.jpegData(compressionQuality: 0.9) {
                    promptParts.append(InlineDataPart(data: avatarJPG, mimeType: "image/jpeg"))
                }
                
                // --- PART C: Garments ---
                promptParts.append(TextPart("\n\nGARMENTS TO WEAR (Layer these onto the mannequin):"))
                for item in selectedClothes {
                    if let url = URL(string: item.remoteURL) {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let rawImg = UIImage(data: data) {
                            let resizedImg = resizeImage(image: rawImg, targetSize: CGSize(width: 512, height: 512)) ?? rawImg
                            if let jpg = resizedImg.jpegData(compressionQuality: 0.8) {
                                promptParts.append(InlineDataPart(data: jpg, mimeType: "image/jpeg"))
                            }
                        }
                    }
                }
                
                // --- PART D: Execute ---
                promptParts.append(TextPart("\n\nGENERATE: The final mannequin image matching the user's measurements and skin tone on a white background."))
                
                // 7. Call Gemini API
                let content = ModelContent(role: "user", parts: promptParts)
                let response = try await imageGenModel.generateContent([content])

                // 8. Handle Response
                if let firstCandidate = response.candidates.first {
                    var foundImage: UIImage? = nil
                    
                    for part in firstCandidate.content.parts {
                        if let inlineData = part as? InlineDataPart,
                           let image = UIImage(data: inlineData.data) {
                            foundImage = image
                            break
                        }
                    }
                    
                    if let image = foundImage {
                        await MainActor.run {
                            self.generatedTryOnImage = image
                            self.isGeneratingTryOn = false
                        }
                    } else if let textPart = firstCandidate.content.parts.first as? TextPart {
                        print("Gemini Text: \(textPart.text)")
                        await MainActor.run {
                            self.tryOnMessage = "Stylist Note: \(textPart.text)"
                            self.isGeneratingTryOn = false
                        }
                    }
                }
            } catch {
                print("DEBUG: Try-On Error - \(error.localizedDescription)")
                await MainActor.run {
                    self.tryOnMessage = "Error: Could not finish styling. Try fewer items."
                    self.isGeneratingTryOn = false
                }
            }
        }
    // MARK: - 6. Save Generated Look
    func saveCurrentLook() async {
        guard let image = generatedTryOnImage, let userEmail = Auth.auth().currentUser?.email else { return }
        
        await MainActor.run { isSavingTryOn = true }
        
        do {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
            let fileName = "generated_\(UUID().uuidString).jpg"
            let storageRef = storage.reference().child("generated_looks/\(fileName)")
            
            _ = try await storageRef.putDataAsync(imageData)
            let downloadURL = try await storageRef.downloadURL()
            
            let customDocID = "\(userEmail)_\(Int(Date().timeIntervalSince1970))"
            try await db.collection("generated_looks").document(customDocID).setData([
                "imageURL": downloadURL.absoluteString,
                "ownerEmail": userEmail,
                "itemsUsed": currentItemsUsed,
                "createdat": FieldValue.serverTimestamp()
            ])
            
            await MainActor.run {
                isSavingTryOn = false
                tryOnSavedSuccess = true
            }
        } catch {
            print("Error saving look: \(error.localizedDescription)")
            await MainActor.run { isSavingTryOn = false }
        }
    }
    
    // MARK: - 7. Helpers
    func updateItemSize(_ item: ClothingItem, newSize: String) {
        let trimmedSize = newSize.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = clothingItems.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = clothingItems[index]
            updatedItem.size = trimmedSize
            clothingItems[index] = updatedItem
        }
        db.collection("clothes").document(item.id).updateData(["size": trimmedSize])
    }
    
    func deleteItem(_ item: ClothingItem) {
        db.collection("clothes").document(item.id).delete()
        if !item.remoteURL.isEmpty {
            storage.reference(forURL: item.remoteURL).delete { _ in }
        }
    }
    
    func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage? {
        let size = image.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        }
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    func fetchUserGender() {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        db.collection("users").document(userEmail).getDocument { [weak self] doc, _ in
            // Fetches gender (e.g., "Male", "Female", "Non-binary")
            if let gender = doc?.get("gender") as? String {
                DispatchQueue.main.async { self?.userGender = gender }
            }
        }
    }
    
    func fetchClothes(for email: String) {
        self.clothingItems = [] // Clear current list to show loading state
        
        // Using "ownerEmail" to match the key used in startFirestoreListener and uploadAndCategorize
        db.collection("clothes")
            .whereField("ownerEmail", isEqualTo: email)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching peer's clothes: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                // Perform the update on the main thread since clothingItems is @Published
                DispatchQueue.main.async {
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
    }
}
