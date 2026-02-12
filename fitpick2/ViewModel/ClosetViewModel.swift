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

    // MARK: - 5. Virtual Try-On Logic
    func generateVirtualTryOn(selectedItemIDs: Set<String>) async {
        print("DEBUG: Starting Try-On Process...")
        await MainActor.run {
            isGeneratingTryOn = true
            generatedTryOnImage = nil
            tryOnMessage = nil
            tryOnSavedSuccess = false
            currentItemsUsed = Array(selectedItemIDs)
        }
        
        // ALWAYS pull the avatar for the person currently holding the phone
        guard let currentUserEmail = Auth.auth().currentUser?.email else { return }
        
        do {
            // Fetch the LOGGED-IN user's avatar, regardless of whose closet we are in
            let userDoc = try await db.collection("users").document(currentUserEmail).getDocument()
            guard let avatarURLString = userDoc.data()?["avatarURL"] as? String,
                  let avatarURL = URL(string: avatarURLString) else {
                await MainActor.run {
                    isGeneratingTryOn = false
                    tryOnMessage = "Please generate your own avatar in your closet first."
                }
                return
            }
            
            let (avatarData, _) = try await URLSession.shared.data(from: avatarURL)
            guard let rawAvatar = UIImage(data: avatarData) else { return }
            let avatarImage = resizeImage(image: rawAvatar, targetSize: CGSize(width: 800, height: 800)) ?? rawAvatar

            let selectedClothes = clothingItems.filter { selectedItemIDs.contains($0.id) }
            let itemDescriptions = selectedClothes.map { "\($0.subCategory) (\($0.category))" }.joined(separator: ", ")
            
            var clothingParts: [any Part] = []
            for item in selectedClothes {
                if let url = URL(string: item.remoteURL) {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let rawImg = UIImage(data: data) {
                        let resizedImg = resizeImage(image: rawImg, targetSize: CGSize(width: 800, height: 800)) ?? rawImg
                        if let jpg = resizedImg.jpegData(compressionQuality: 0.6) {
                            clothingParts.append(InlineDataPart(data: jpg, mimeType: "image/jpeg"))
                        }
                    }
                }
            }

            let promptText = """
            TASK: 3D Avatar Texture Editing.
            Target Gender: \(userGender).
            INPUT ROLES:
            - Image 1: BASE 3D MODEL (Avatar).
            - Images 2+: TEXTURE REFERENCES (Clothes).
            INSTRUCTIONS:
            - Dress the Avatar in the clothes.
            - KEEP Avatar's identity/face 100% unchanged.
            - NO PHOTOREALISM. Maintain 3D render style.
            - Output single full-body image.
            OUTFIT SPECS: \(itemDescriptions).
            """
            
            var parts: [any Part] = []
            parts.append(TextPart(promptText))
            if let avatarJPEG = avatarImage.jpegData(compressionQuality: 0.6) {
                parts.append(InlineDataPart(data: avatarJPEG, mimeType: "image/jpeg"))
            }
            parts.append(contentsOf: clothingParts)
            
            let content = ModelContent(role: "user", parts: parts)
            let response = try await imageGenModel.generateContent([content])

            if let firstCandidate = response.candidates.first,
               let firstPart = firstCandidate.content.parts.first {
                
                if let inlineData = firstPart as? InlineDataPart,
                   let generatedImage = UIImage(data: inlineData.data) {
                    await MainActor.run {
                        self.generatedTryOnImage = generatedImage
                        self.isGeneratingTryOn = false
                    }
                } else if let textPart = firstPart as? TextPart {
                    await MainActor.run {
                        self.tryOnMessage = "Stylist Note: \(textPart.text)"
                        self.isGeneratingTryOn = false
                    }
                }
            }
        } catch {
            print("DEBUG: Error - \(error.localizedDescription)")
            await MainActor.run { isGeneratingTryOn = false }
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
