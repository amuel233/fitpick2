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
import Kingfisher
import Vision // Required for Image Validation

// MARK: - Models

/// Represents a previously generated outfit saved in Firestore history
struct SavedLook: Identifiable {
    let id: String
    let imageURL: String
    let date: Date
    let itemsUsed: [String] // IDs of clothes used in this look
}

@MainActor
class ClosetViewModel: ObservableObject {
    
    // MARK: - Properties
    
    // --- Guest Mode Logic ---
    private let targetEmail: String?
    
    // Computed property to determine whose data to fetch
    private var effectiveEmail: String? {
        return targetEmail ?? Auth.auth().currentUser?.email
    }
    
    // --- Data Source ---
    @Published var clothingItems: [ClothingItem] = []
    
    // --- History / Saved Looks ---
    @Published var savedLooks: [SavedLook] = []
    @Published var isRestoringLook = false
    
    // --- UI States ---
    @Published var isUploading = false         // For Add Item Spinner
    @Published var isGeneratingTryOn = false   // For Try-On Spinner
    @Published var isSavingTryOn = false       // For Save Look Spinner
    @Published var tryOnSavedSuccess = false
    
    // --- Try-On Results ---
    @Published var generatedTryOnImage: UIImage? = nil
    @Published var tryOnMessage: String? = nil
    
    // --- User Context ---
    @Published var userGender: String = "Male"
    @Published var isSaved: Bool = false
    @Published var currentUser: User? // Holds full user object for avatar display
    
    // Internal Tracker
    private var currentItemsUsed: [String] = []
    
    // --- Firebase Services ---
    private let ai = FirebaseAI.firebaseAI(backend: .googleAI())
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var listener: ListenerRegistration?
    private var historyListener: ListenerRegistration?
    
    // AI Model
    private lazy var imageGenModel = ai.generativeModel(modelName: "gemini-3-pro-image-preview")

    //Avatar Listener for closetHeaderView
    @Published var userAvatarURL: String? = nil
    private var userListener: ListenerRegistration?
    
    // MARK: - MVVM View State
    
    // 1. Filter State
    @Published var selectedCategory: ClothingCategory? = nil
    
    // 2. Selection State
    @Published var selectedItemIDs: Set<String> = []
    
    // 3. Computed Data for Grid
    var filteredItems: [ClothingItem] {
        guard let category = selectedCategory else { return clothingItems }
        return clothingItems.filter { $0.category == category }
    }
    
    // 4. Intents (Actions)
    func toggleSelection(_ item: ClothingItem) {
        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
        }
    }
    
    func clearSelection() {
        selectedItemIDs.removeAll()
    }

    
    // MARK: - Initialization
    
    init(targetEmail: String? = nil) {
        // --- Cache Configuration ---
        // 50MB Memory / 1GB Disk / 30 Days Duration
        ImageCache.default.memoryStorage.config.totalCostLimit = 50 * 1024 * 1024
        ImageCache.default.diskStorage.config.sizeLimit = 1000 * 1024 * 1024
        ImageCache.default.diskStorage.config.expiration = .days(30)
        
        self.targetEmail = targetEmail
        
        // Start Data Flow
        Task { await fetchClothingItems() }
        
        if targetEmail == nil {
            listenToSavedLooks()
        }
        listenToUserProfile()
    }
    
    deinit {
        listener?.remove()
        historyListener?.remove()
        userListener?.remove() // <--- Clean up
    }
    
    // MARK: - 1. Data Fetching
    
    /// Main function to fetch items (Real-time Listener)
    func fetchClothingItems() async {
        guard let email = effectiveEmail else { return }
        
        listener = db.collection("clothes")
            .whereField("ownerEmail", isEqualTo: email)
            .order(by: "createdat", descending: true)
            .addSnapshotListener { [weak self] querySnapshot, _ in
                guard let documents = querySnapshot?.documents else { return }
                self?.clothingItems = documents.compactMap { self?.mapDocumentToItem($0) }
            }
    }
    
    // MARK: - Firestore Mapper (Universal Compatibility)
    private func mapDocumentToItem(_ document: QueryDocumentSnapshot) -> ClothingItem? {
        let data = document.data()
        
        // 1. UNIVERSAL URL CHECK
        // Try "remoteURL" (Manual) OR "imageURL" (Smart Scan/Legacy)
        guard let urlString = data["remoteURL"] as? String ?? data["imageURL"] as? String else {
            // print("⚠️ Skipped Item \(document.documentID): No Image URL found.")
            return nil
        }
        
        // 2. UNIVERSAL SUBCATEGORY CHECK
        // Try "subCategory" (CamelCase) OR "subcategory" (Lowercase) -> Default to "Clothing"
        let subCategory = data["subCategory"] as? String ?? data["subcategory"] as? String ?? "Clothing"
        
        // 3. ROBUST CATEGORY MATCHING
        let rawCat = data["category"] as? String ?? "Top"
        let category: ClothingCategory
        
        // Handle Capitalization/Plurals/Synonyms
        if let exactMatch = ClothingCategory(rawValue: rawCat) {
            category = exactMatch
        } else {
            let normalized = rawCat.lowercased().trimmingCharacters(in: .whitespaces)
            switch normalized {
            case "top", "tops", "t-shirt", "shirt", "blouse": category = .top
            case "bottom", "bottoms", "pant", "pants", "jeans", "shorts", "skirt": category = .bottom
            case "shoe", "shoes", "sneakers", "boots", "footwear": category = .shoes
            case "accessories", "accessory", "hat", "bag", "jewelry": category = .accessories
            default: category = .top // Fallback
            }
        }
        
        // 4. SIZE CHECK
        let size = data["size"] as? String ?? ""
        
        // 5. Create Item
        return ClothingItem(
            id: document.documentID,
            remoteURL: urlString,
            category: category,
            subCategory: subCategory,
            size: size
        )
    }
    
    func listenToUserProfile() {
            guard let email = effectiveEmail else { return }
            
            // Real-time listener: Updates instantly when Firebase changes
            userListener = db.collection("users").document(email)
                .addSnapshotListener { [weak self] documentSnapshot, error in
                    guard let document = documentSnapshot, document.exists, let data = document.data() else { return }
                    
                    DispatchQueue.main.async {
                        // 1. Get Avatar URL
                        self?.userAvatarURL = data["avatarURL"] as? String
                        
                        // 2. Get Gender (for Try-On logic)
                        self?.userGender = data["gender"] as? String ?? "Male"
                        
                        // 3. (Optional) Get other measurements if needed
                        // self?.currentUser = ...
                    }
                }
        }

    // MARK: - 2. Virtual Try-On Logic
    
    func generateVirtualTryOn(selectedItemIDs: Set<String>) async {
        print("DEBUG: Starting Try-On Generation...")
        
        isGeneratingTryOn = true
        generatedTryOnImage = nil
        tryOnMessage = nil
        tryOnSavedSuccess = false
        isSaved = false
        currentItemsUsed = Array(selectedItemIDs)
        
        // Filter & Validate
        let selectedClothes = clothingItems.filter { selectedItemIDs.contains($0.id) }
        
        // "One-Piece" detection (Dress/Jumpsuit)
        let fullBodyItems = selectedClothes.filter { item in
            let sub = item.subCategory.lowercased()
            return sub.contains("dress") || sub.contains("jumpsuit") || sub.contains("romper") || sub.contains("gown") || sub.contains("one-piece")
        }
        let fullBodyIDs = Set(fullBodyItems.map { $0.id })
        
        let tops = selectedClothes.filter { $0.category == .top && !fullBodyIDs.contains($0.id) }
        let bottoms = selectedClothes.filter { $0.category == .bottom && !fullBodyIDs.contains($0.id) }
        let shoes = selectedClothes.filter { $0.category == .shoes }
        
        // Validation Rules
        if shoes.count > 1 { isGeneratingTryOn = false; tryOnMessage = "Please select only 1 pair of shoes."; return }
        if !fullBodyItems.isEmpty {
            if !bottoms.isEmpty { isGeneratingTryOn = false; tryOnMessage = "You cannot wear a Dress and Bottoms together."; return }
            if fullBodyItems.count > 1 { isGeneratingTryOn = false; tryOnMessage = "Please select only 1 Full-Body outfit."; return }
        }
        if fullBodyItems.isEmpty && bottoms.count > 1 { isGeneratingTryOn = false; tryOnMessage = "Please select only 1 Bottom."; return }
        if tops.count > 2 { isGeneratingTryOn = false; tryOnMessage = "Layering Limit: Max 2 Tops."; return }
        
        // Fetch User Context
        guard let email = effectiveEmail else { return }
        
        do {
            let userDoc = try await db.collection("users").document(email).getDocument()
            let userData = userDoc.data()
            
            guard let avatarURLString = userData?["avatarURL"] as? String,
                  let avatarURL = URL(string: avatarURLString) else {
                isGeneratingTryOn = false; tryOnMessage = "Avatar not found. Please tap 'Sparkles' to generate one."
                return
            }
            
            let gender = userData?["gender"] as? String ?? "Neutral"
            var measurementString = "Standard Average Build"
            if let m = userData?["measurements"] as? [String: Any] {
                let h = m["height"] as? Double ?? 0
                let w = m["bodyWeight"] as? Double ?? 0
                measurementString = "Height: \(h)cm, Weight: \(w)kg"
            }
            
            // Download Avatar
            let (avatarData, _) = try await URLSession.shared.data(from: avatarURL)
            guard let rawAvatar = UIImage(data: avatarData) else { return }
            let baseAvatarImage = resizeImage(image: rawAvatar, targetSize: CGSize(width: 1024, height: 1024)) ?? rawAvatar

            // Construct Prompt
            var promptParts: [any Part] = []
            
            promptParts.append(TextPart("""
            ROLE: Virtual Fashion Stylist.
            TASK: Generate a high-quality fashion visualization of a mannequin wearing the selected outfit.
            
            VISUAL REQUIREMENTS (STRICT):
            1. POSE: Front-facing, standing straight. Arms slightly away from body (A-Pose).
            
            2. BODY & GENDER (CRITICAL):
               - Target Gender: \(gender).
               - The mannequin structure must reflect a \(gender) physique.
               - Match these User Measurements: \(measurementString).
               - Sample the SKIN TONE from the Reference Image (Image 1).
            
            3. HEAD & FACE:
               - Render a DEFINED MANNEQUIN HEAD. Do not crop the head.
               - The face must be ABSTRACT/STYLIZED (smooth features).
               - DO NOT generate a realistic human face.
            
            4. BACKGROUND: Pure White (#FFFFFF).
            """))
            
            promptParts.append(TextPart("\n\nREFERENCE IMAGE (For Skin Tone & Body Shape):"))
            if let avatarJPG = baseAvatarImage.jpegData(compressionQuality: 0.9) {
                promptParts.append(InlineDataPart(data: avatarJPG, mimeType: "image/jpeg"))
            }
            
            promptParts.append(TextPart("\n\nGARMENTS TO WEAR:"))
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
            
            promptParts.append(TextPart("\n\nGENERATE: The final mannequin image."))
            
            // Generate
            let content = ModelContent(role: "user", parts: promptParts)
            let response = try await imageGenModel.generateContent([content])

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
                    self.generatedTryOnImage = image
                    self.isGeneratingTryOn = false
                } else if let textPart = firstCandidate.content.parts.first as? TextPart {
                    print("Gemini Text: \(textPart.text)")
                    self.tryOnMessage = "Stylist Note: \(textPart.text)"
                    self.isGeneratingTryOn = false
                }
            }
        } catch {
            print("DEBUG: Try-On Error - \(error.localizedDescription)")
            self.tryOnMessage = "Error: Could not finish styling. Try fewer items."
            self.isGeneratingTryOn = false
        }
    }
    
    // MARK: - 3. Add Item Logic
    
    // Manual Save (Supports Bulk Upload)
    func saveManualItem(image: UIImage, category: ClothingCategory, subCategory: String, size: String) async {
        guard let user = Auth.auth().currentUser else { return }
        
        // 1. Compress Image
        guard let imageData = image.jpegData(compressionQuality: 0.6) else { return }
        
        // 2. Upload to Storage
        let filename = "\(UUID().uuidString).jpg"
        let storageRef = Storage.storage().reference().child("users/\(user.uid)/closet/\(filename)")
        
        do {
            let _ = try await storageRef.putDataAsync(imageData)
            let downloadURL = try await storageRef.downloadURL()
            
            // 3. Create the New Item Model
            let newItem = ClothingItem(
                id: UUID().uuidString,
                remoteURL: downloadURL.absoluteString,
                category: category,
                subCategory: subCategory,
                size: size
            )
            
            // 4. Save to Firestore
            try await Firestore.firestore()
                .collection("users") // Or "clothes" depending on your data model preference, but keeping consistency with prompt
                .document(user.uid)
                .collection("closet") // OR .collection("clothes") - CHECK YOUR DB STRUCTURE
                .document(newItem.id)
                .setData([
                    "id": newItem.id,
                    "remoteURL": newItem.remoteURL,
                    "category": newItem.category.rawValue,
                    "subCategory": newItem.subCategory,
                    "size": newItem.size,
                    "ownerEmail": user.email ?? "", // Important for listener
                    "createdat": FieldValue.serverTimestamp()
                ])
            
            // Also save to root 'clothes' collection if that's where your listener looks
            try await Firestore.firestore().collection("clothes").document(newItem.id).setData([
                "remoteURL": newItem.remoteURL,
                "category": newItem.category.rawValue,
                "subCategory": newItem.subCategory,
                "size": newItem.size,
                "ownerEmail": user.email ?? "",
                "createdat": FieldValue.serverTimestamp()
            ])
                
            // 5. Update Local State (UI)
            self.clothingItems.append(newItem)
            print("✅ Successfully saved: \(subCategory)")
            
        } catch {
            print("❌ Failed to save item: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Smart Scan / LiDAR Logic
        
        /// Logic to determine size from measurements (Heuristic)
        func determineSizeFromAutoMeasurements(width: Double, length: Double, category: String, subCategory: String) async -> String {
            // Simple Heuristic Algorithm
            if category == "Top" {
                if width < 19 { return "XS" }
                else if width < 21 { return "S" }
                else if width < 23 { return "M" }
                else if width < 25 { return "L" }
                else { return "XL" }
            } else if category == "Bottom" {
                // Estimate waist from width (very rough approximation for 2D flat lay)
                let waist = Int(width * 2)
                return "W\(waist)"
            }
            return "Unknown"
        }

        /// Saves an Auto-Measured item (LiDAR / Smart Scan)
        func saveAutoMeasuredItem(image: UIImage, category: String, subCategory: String, size: String, width: Double, length: Double) async {
            guard let user = Auth.auth().currentUser else { return }
            
            await MainActor.run { isUploading = true }
            
            do {
                guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
                let fileName = "smart_\(UUID().uuidString).jpg"
                let storageRef = storage.reference().child("users/\(user.uid)/closet/\(fileName)")
                
                _ = try await storageRef.putDataAsync(imageData)
                let downloadURL = try await storageRef.downloadURL()
                
                // Map String category to Enum
                let catEnum = ClothingCategory(rawValue: category) ?? .top
                
                let newItem = ClothingItem(
                    id: UUID().uuidString,
                    remoteURL: downloadURL.absoluteString,
                    category: catEnum,
                    subCategory: subCategory,
                    size: size
                )
                
                // Save to Firestore
                try await db.collection("users").document(user.uid).collection("closet").document(newItem.id).setData([
                    "id": newItem.id,
                    "remoteURL": newItem.remoteURL,
                    "category": newItem.category.rawValue,
                    "subCategory": newItem.subCategory,
                    "size": newItem.size,
                    "measurements": ["width": width, "length": length], // Store raw data
                    "isAutoMeasured": true,
                    "createdat": FieldValue.serverTimestamp()
                ])
                
                await MainActor.run {
                    self.clothingItems.append(newItem)
                    self.isUploading = false
                }
                print("✅ Smart item saved successfully.")
                
            } catch {
                print("❌ Error saving smart item: \(error.localizedDescription)")
                await MainActor.run { isUploading = false }
            }
        }
        
        /// Updates just the size of an item (used in Edit Mode)
        func updateItemSize(_ item: ClothingItem, newSize: String) {
            guard let user = Auth.auth().currentUser else { return }
            
            // Update Local
            if let index = clothingItems.firstIndex(where: { $0.id == item.id }) {
                var updatedItem = item
                updatedItem.size = newSize
                clothingItems[index] = updatedItem
            }
            
            // Update Remote
            db.collection("users").document(user.uid).collection("closet").document(item.id).updateData(["size": newSize])
        }
    
    // Logic to delete an item
    func deleteItem(_ item: ClothingItem) {
        // 1. UI Optimistic Update
        withAnimation {
            self.clothingItems.removeAll { $0.id == item.id }
        }
        // 2. Firestore
        db.collection("clothes").document(item.id).delete()
        // 3. Storage
        storage.reference(forURL: item.remoteURL).delete { _ in }
    }

    // MARK: - 4. History / Saved Looks Logic
    
    func listenToSavedLooks() {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        
        historyListener = db.collection("generated_looks")
            .whereField("ownerEmail", isEqualTo: userEmail)
            .order(by: "createdat", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self?.savedLooks = documents.compactMap { doc -> SavedLook? in
                        let data = doc.data()
                        guard let url = data["imageURL"] as? String else { return nil }
                        let timestamp = data["createdat"] as? Timestamp
                        let items = data["itemsUsed"] as? [String] ?? []
                        
                        return SavedLook(
                            id: doc.documentID,
                            imageURL: url,
                            date: timestamp?.dateValue() ?? Date(),
                            itemsUsed: items
                        )
                    }
                }
            }
    }
    
    func restoreLook(_ look: SavedLook) async {
        isRestoringLook = true
        generatedTryOnImage = nil
        tryOnMessage = nil
        
        do {
            guard let url = URL(string: look.imageURL) else { return }
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                self.generatedTryOnImage = image
                self.isRestoringLook = false
                self.currentItemsUsed = look.itemsUsed
                self.isSaved = true
            }
        } catch {
            isRestoringLook = false
        }
    }
    
    func deleteLook(_ look: SavedLook) {
        withAnimation { self.savedLooks.removeAll { $0.id == look.id } }
        ImageCache.default.removeImage(forKey: look.imageURL)
        db.collection("generated_looks").document(look.id).delete()
        storage.reference(forURL: look.imageURL).delete { _ in }
    }
    
    // MARK: - Save Generated Look (FIXED & READABLE)
    func saveCurrentLook() async {
        guard let image = generatedTryOnImage,
              let user = Auth.auth().currentUser else { return }
        
        isSavingTryOn = true
        
        // 1. Prepare Filename
        let rawName = user.displayName ?? "user"
        let safeName = rawName.components(separatedBy: .whitespacesAndNewlines).joined(separator: "_")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = formatter.string(from: Date())
        let filename = "\(safeName)_LOOK_\(dateString).jpg"
        
        // 2. Compress
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            isSavingTryOn = false
            return
        }
        
        let storageRef = Storage.storage().reference().child("users/\(user.uid)/generated_looks/\(filename)")
        
        do {
            // 3. Upload to Storage
            let _ = try await storageRef.putDataAsync(imageData)
            let downloadURL = try await storageRef.downloadURL()
            
            // 4. SAVE TO FIRESTORE (Crucial for History!)
            let lookID = UUID().uuidString
            try await db.collection("generated_looks").document(lookID).setData([
                "id": lookID,
                "imageURL": downloadURL.absoluteString,
                "ownerEmail": user.email ?? "",
                "itemsUsed": currentItemsUsed,
                "createdat": FieldValue.serverTimestamp()
            ])
            
            // 5. Success
            isSavingTryOn = false
            isSaved = true
            print("✅ Saved Look: \(filename)")
            
        } catch {
            print("❌ Failed to save look: \(error.localizedDescription)")
            isSavingTryOn = false
        }
    }
    
    // MARK: - Helpers
    
    func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage? {
        let size = image.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        var newSize: CGSize
        if(widthRatio > heightRatio) { newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio) }
        else { newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio) }
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }

    // MARK: - Image Validation (Strict Vision Mode)
    func validateImageIsClothing(_ image: UIImage) async -> Bool {
        guard let cgImage = image.cgImage else { return false }
        
        return await Task.detached(priority: .userInitiated) {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            var isClothing = false
            
            let request = VNClassifyImageRequest { request, error in
                if let error = error { print("Vision Error: \(error)"); return }
                guard let results = request.results as? [VNClassificationObservation] else { return }
                
                let topResults = results.prefix(3)
                
                // Blacklist Check
                let blacklist = ["tree", "plant", "flower", "nature", "vehicle", "car", "food", "animal", "building"]
                for result in topResults {
                    if blacklist.contains(where: { result.identifier.lowercased().contains($0) }) {
                        isClothing = false
                        return
                    }
                }
                
                // Whitelist Check
                let whitelist = ["clothing", "shirt", "top", "pants", "dress", "jacket", "shoe", "hat", "bag", "accessory", "uniform", "jersey"]
                isClothing = topResults.contains { observation in
                    let id = observation.identifier.lowercased()
                    return whitelist.contains { id.contains($0) }
                }
            }
            
            do {
                try handler.perform([request])
                return isClothing
            } catch {
                #if targetEnvironment(simulator)
                return true // Simulator bypass
                #else
                return false
                #endif
            }
        }.value
    }
}
