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

// MARK: - Models

/// Represents a previously generated outfit saved in Firestore history
struct SavedLook: Identifiable {
    let id: String
    let imageURL: String
    let date: Date
    let itemsUsed: [String] // IDs of clothes used in this look
}

class ClosetViewModel: ObservableObject {
    
    // MARK: - Properties
    
    // --- Guest Mode Logic ---
    // If targetEmail is set, we are viewing someone else's closet.
    // If nil, we are viewing our own.
    private let targetEmail: String?
    
    // Computed property to determine whose data to fetch (Target or Current User)
    private var effectiveEmail: String? {
        return targetEmail ?? Auth.auth().currentUser?.email
    }
    
    // --- Data Source ---
    @Published var clothingItems: [ClothingItem] = []
    
    // --- History / Saved Looks ---
    @Published var savedLooks: [SavedLook] = []
    @Published var isRestoringLook = false // Shows loading spinner when restoring a look
    
    // --- UI States ---
    @Published var isUploading = false         // For Add Item Spinner
    @Published var isGeneratingTryOn = false   // For Try-On Spinner
    @Published var isSavingTryOn = false       // For Save Look Spinner
    @Published var tryOnSavedSuccess = false
    
    // --- Try-On Results ---
    @Published var generatedTryOnImage: UIImage? = nil
    @Published var tryOnMessage: String? = nil
    
    // --- User Context ---
    @Published var userGender: String = "Male" // Defaults to Male, updated via fetch
    @Published var isSaved: Bool = false       // Tracks if current try-on is already saved
    
    // Internal Tracker (Used to prevent duplicate saves)
    private var currentItemsUsed: [String] = []
    
    // --- Firebase Services ---
    private let ai = FirebaseAI.firebaseAI(backend: .googleAI())
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var listener: ListenerRegistration?
    private var historyListener: ListenerRegistration?
    
    // AI Model
    private lazy var imageGenModel = ai.generativeModel(modelName: "gemini-2.5-flash-image")

    // MARK: - Initialization
    
    /// Initialize with an optional targetEmail.
    /// - Parameter targetEmail: If provided, loads that user's closet. If nil, loads current user's closet.
    init(targetEmail: String? = nil) {
        self.targetEmail = targetEmail
        
        // 1. Fetch Clothes (For Target or Self)
        startFirestoreListener()
        
        // 2. Fetch History (ONLY for Self - Privacy Rule)
        if targetEmail == nil {
            listenToSavedLooks()
        }
        
        // 3. Fetch Gender (For correct mannequin shape)
        fetchUserGender()
    }
    
    deinit {
        listener?.remove()
        historyListener?.remove()
    }
    
    // MARK: - 1. Data Fetching (Core)
    
    /// Real-time listener for the "clothes" collection.
    func startFirestoreListener() {
        guard let email = effectiveEmail else { return }
        
        listener = db.collection("clothes")
            .whereField("ownerEmail", isEqualTo: email)
            .order(by: "createdat", descending: true)
            .addSnapshotListener { [weak self] querySnapshot, _ in
                guard let documents = querySnapshot?.documents else { return }
                self?.clothingItems = documents.compactMap { doc -> ClothingItem? in
                    let data = doc.data()
                    return ClothingItem(
                        id: doc.documentID,
                        image: Image(systemName: "photo"), // Placeholder
                        uiImage: nil,
                        category: ClothingCategory(rawValue: data["category"] as? String ?? "") ?? .top,
                        subCategory: data["subcategory"] as? String ?? "Other",
                        remoteURL: data["imageURL"] as? String ?? "",
                        size: data["size"] as? String ?? "Unknown"
                    )
                }
            }
    }
    
    /// Fetches gender to ensure the mannequin matches the user.
    func fetchUserGender() {
        guard let email = effectiveEmail else { return }
        db.collection("users").document(email).getDocument { [weak self] doc, _ in
            if let gender = doc?.get("gender") as? String {
                DispatchQueue.main.async { self?.userGender = gender }
            }
        }
    }

    // MARK: - 2. Virtual Try-On Logic (The Brain)
    
    /// Generates a "Ghost Mannequin" visualization.
    /// Features:
    /// - Validates outfit combinations (e.g., prevents 2 pants).
    /// - Injects User GENDER and MEASUREMENTS for accurate body shape.
    /// - Requests a visible, abstract mannequin head.
    func generateVirtualTryOn(selectedItemIDs: Set<String>) async {
        print("DEBUG: Starting Try-On Generation...")
        
        // 1. Reset UI State
        await MainActor.run {
            isGeneratingTryOn = true
            generatedTryOnImage = nil
            tryOnMessage = nil
            tryOnSavedSuccess = false
            isSaved = false // New generation is unsaved by default
            currentItemsUsed = Array(selectedItemIDs)
        }
        
        // 2. CLOTHING VALIDATION (Guardrails)
        let selectedClothes = clothingItems.filter { selectedItemIDs.contains($0.id) }
        
        // Identify "Full Body" items via string check
        let fullBodyItems = selectedClothes.filter { item in
            let sub = item.subCategory.lowercased()
            return sub.contains("dress") || sub.contains("jumpsuit") || sub.contains("romper") || sub.contains("gown") || sub.contains("one-piece")
        }
        
        let fullBodyIDs = Set(fullBodyItems.map { $0.id })
        
        // Split into categories
        let tops = selectedClothes.filter { $0.category == .top && !fullBodyIDs.contains($0.id) }
        let bottoms = selectedClothes.filter { $0.category == .bottom && !fullBodyIDs.contains($0.id) }
        let shoes = selectedClothes.filter { $0.category == .shoes }
        
        // Rules
        if shoes.count > 1 { await MainActor.run { isGeneratingTryOn = false; tryOnMessage = "Please select only 1 pair of shoes." }; return }
        
        if !fullBodyItems.isEmpty {
            if !bottoms.isEmpty { await MainActor.run { isGeneratingTryOn = false; tryOnMessage = "You cannot wear a Dress and Bottoms together." }; return }
            if fullBodyItems.count > 1 { await MainActor.run { isGeneratingTryOn = false; tryOnMessage = "Please select only 1 Full-Body outfit." }; return }
        }
        
        if fullBodyItems.isEmpty && bottoms.count > 1 { await MainActor.run { isGeneratingTryOn = false; tryOnMessage = "Please select only 1 Bottom." }; return }
        
        if tops.count > 2 { await MainActor.run { isGeneratingTryOn = false; tryOnMessage = "Layering Limit: Max 2 Tops." }; return }
        
        // 3. Auth Check & Context Fetching
        // We use effectiveEmail here to get the avatar of the closet owner
        guard let email = effectiveEmail else { return }
        
        do {
            // 4. Fetch Context Data
            let userDoc = try await db.collection("users").document(email).getDocument()
            let userData = userDoc.data()
            
            // Get Avatar (Reference Image)
            guard let avatarURLString = userData?["avatarURL"] as? String,
                  let avatarURL = URL(string: avatarURLString) else {
                await MainActor.run { isGeneratingTryOn = false; tryOnMessage = "Avatar not found for this user." }
                return
            }
            
            // Get Gender & Measurements
            let gender = userData?["gender"] as? String ?? "Neutral"
            
            var measurementString = "Standard Average Build"
            if let m = userData?["measurements"] as? [String: Any] {
                let h = m["height"] as? Double ?? 0
                let w = m["bodyWeight"] as? Double ?? 0
                let chest = m["chest"] as? Double ?? 0
                let waist = m["waist"] as? Double ?? 0
                let hips = m["hips"] as? Double ?? 0
                measurementString = "Height: \(h)cm, Weight: \(w)kg, Chest: \(chest)cm, Waist: \(waist)cm, Hips: \(hips)cm"
            }
            
            // 5. Download Reference Avatar
            let (avatarData, _) = try await URLSession.shared.data(from: avatarURL)
            guard let rawAvatar = UIImage(data: avatarData) else { return }
            let baseAvatarImage = resizeImage(image: rawAvatar, targetSize: CGSize(width: 1024, height: 1024)) ?? rawAvatar

            // 6. Construct Prompt
            var promptParts: [any Part] = []
            
            // System Instructions
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
            
            // Append Avatar Reference
            promptParts.append(TextPart("\n\nREFERENCE IMAGE (For Skin Tone & Body Shape):"))
            if let avatarJPG = baseAvatarImage.jpegData(compressionQuality: 0.9) {
                promptParts.append(InlineDataPart(data: avatarJPG, mimeType: "image/jpeg"))
            }
            
            // Append Clothing Images
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
            
            // 7. Execute Generation
            let content = ModelContent(role: "user", parts: promptParts)
            let response = try await imageGenModel.generateContent([content])

            // 8. Handle Response
            if let firstCandidate = response.candidates.first {
                var foundImage: UIImage? = nil
                
                // Scan for image data
                for part in firstCandidate.content.parts {
                    if let inlineData = part as? InlineDataPart,
                       let image = UIImage(data: inlineData.data) {
                        foundImage = image
                        break
                    }
                }
                
                // Update UI
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
    
    // MARK: - 3. Save / Add Item Logic
    
    /// Saves a Manually Added item (From AddItemSheet)
    func saveManualItem(image: UIImage, category: ClothingCategory, subCategory: String, size: String) async {
        // ALWAYS save to current user's closet, even if viewing someone else's
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        
        await MainActor.run { isUploading = true }
        
        do {
            // Upload
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
            let fileName = "\(UUID().uuidString).jpg"
            let storageRef = storage.reference().child("clothes/\(fileName)")
            
            _ = try await storageRef.putDataAsync(imageData)
            let downloadURL = try await storageRef.downloadURL()
            
            // Save Metadata
            try await db.collection("clothes").addDocument(data: [
                "imageURL": downloadURL.absoluteString,
                "ownerEmail": userEmail,
                "category": category.rawValue,
                "subcategory": subCategory,
                "size": size,
                "createdat": FieldValue.serverTimestamp()
            ])
            
            await MainActor.run { isUploading = false }
            print("Manual item saved successfully.")
            
        } catch {
            print("Error saving item: \(error.localizedDescription)")
            await MainActor.run { isUploading = false }
        }
    }
    
    /// Saves an Auto-Measured item (From SmartAddItemSheet)
    func saveAutoMeasuredItem(image: UIImage, category: String, subCategory: String, size: String, width: Double, length: Double) async {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        
        await MainActor.run { isUploading = true }
        
        do {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
            let fileName = "smart_\(UUID().uuidString).jpg"
            let storageRef = storage.reference().child("clothes/\(fileName)")
            
            _ = try await storageRef.putDataAsync(imageData)
            let downloadURL = try await storageRef.downloadURL()
            
            try await db.collection("clothes").addDocument(data: [
                "imageURL": downloadURL.absoluteString,
                "ownerEmail": userEmail,
                "category": category,
                "subcategory": subCategory,
                "size": size,
                "measurements": ["width": width, "length": length],
                "isAutoMeasured": true,
                "createdat": FieldValue.serverTimestamp()
            ])
            
            await MainActor.run { isUploading = false }
        } catch {
            print("Error saving smart item: \(error.localizedDescription)")
            await MainActor.run { isUploading = false }
        }
    }
    
    /// Logic to determine size from LiDAR measurements
    func determineSizeFromAutoMeasurements(width: Double, length: Double, category: String, subCategory: String) async -> String {
        // Basic Heuristic
        if category == "Top" {
            if width < 19 { return "S" }
            else if width < 21 { return "M" }
            else if width < 23 { return "L" }
            else { return "XL" }
        } else if category == "Bottom" {
            let waist = Int(width * 2)
            return "W\(waist) L\(Int(length))"
        }
        return "Unknown"
    }

    // MARK: - 4. History / Saved Looks Logic
    
    /// Listens to the user's generated looks history.
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
    
    /// Restores a look from history to the main viewer.
    func restoreLook(_ look: SavedLook) async {
        await MainActor.run {
            isRestoringLook = true
            generatedTryOnImage = nil
            tryOnMessage = nil
        }
        
        do {
            guard let url = URL(string: look.imageURL) else { return }
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.generatedTryOnImage = image
                    self.isRestoringLook = false
                    self.currentItemsUsed = look.itemsUsed
                    self.isSaved = true
                }
            }
        } catch {
            await MainActor.run { isRestoringLook = false }
        }
    }
    
    /// Deletes a look from history.
    func deleteLook(_ look: SavedLook) {
        db.collection("generated_looks").document(look.id).delete()
        let storageRef = storage.reference(forURL: look.imageURL)
        storageRef.delete { _ in }
    }
    
    /// Saves the currently generated try-on to history.
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
                isSaved = true
            }
        } catch {
            print("Error saving look: \(error.localizedDescription)")
            await MainActor.run { isSavingTryOn = false }
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
}
