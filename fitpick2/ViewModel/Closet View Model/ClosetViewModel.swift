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
// MARK: - Image Validation (Anti-Hallucination)
import Vision // Ensure this is imported at the top


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
    
    // Internal Tracker
    private var currentItemsUsed: [String] = []
    
    // --- Firebase Services ---
    private let ai = FirebaseAI.firebaseAI(backend: .googleAI())
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var listener: ListenerRegistration?
    private var historyListener: ListenerRegistration?
    
    // AI Model
    private lazy var imageGenModel = ai.generativeModel(modelName: "gemini-2.5-flash-image")

// MARK: - MVVM View State (Added)
    
    // 1. Filter State
    @Published var selectedCategory: ClothingCategory? = nil
    
    // 2. Selection State
    @Published var selectedItemIDs: Set<String> = []
    
    // 3. Computed Data for Grid
    // The View just asks for "filteredItems" and gets the correct list instantly.
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
        self.targetEmail = targetEmail
        
        // 1. Fetch Clothes (Target or Self)
        startFirestoreListener()
        
        // 2. Fetch History (ONLY for Self)
        if targetEmail == nil {
            listenToSavedLooks()
        }
        
        // 3. Fetch Gender
        fetchUserGender()
    }
    
    deinit {
        listener?.remove()
        historyListener?.remove()
    }
    
    // MARK: - 1. Data Fetching
    
    func fetchClothes(for email: String) {
           // If you want a manual fetch trigger
           db.collection("clothes")
               .whereField("ownerEmail", isEqualTo: email)
               .order(by: "createdat", descending: true)
               .getDocuments { [weak self] snapshot, _ in
                   guard let documents = snapshot?.documents else { return }
                   DispatchQueue.main.async {
                       self?.clothingItems = documents.compactMap { self?.mapDocumentToItem($0) }
                   }
               }
       }
    
    func startFirestoreListener() {
        guard let email = effectiveEmail else { return }
        
        listener = db.collection("clothes")
            .whereField("ownerEmail", isEqualTo: email)
            .order(by: "createdat", descending: true)
            .addSnapshotListener { [weak self] querySnapshot, _ in
                guard let documents = querySnapshot?.documents else { return }
                self?.clothingItems = documents.compactMap { self?.mapDocumentToItem($0) }
            }
    }
    
    private func mapDocumentToItem(_ doc: QueryDocumentSnapshot) -> ClothingItem {
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
    
    func fetchUserGender() {
        guard let email = effectiveEmail else { return }
        db.collection("users").document(email).getDocument { [weak self] doc, _ in
            if let gender = doc?.get("gender") as? String {
                DispatchQueue.main.async { self?.userGender = gender }
            }
        }
    }

    // MARK: - 2. Virtual Try-On Logic
    
    func generateVirtualTryOn(selectedItemIDs: Set<String>) async {
        print("DEBUG: Starting Try-On Generation...")
        
        await MainActor.run {
            isGeneratingTryOn = true
            generatedTryOnImage = nil
            tryOnMessage = nil
            tryOnSavedSuccess = false
            isSaved = false
            currentItemsUsed = Array(selectedItemIDs)
        }
        
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
        if shoes.count > 1 { await MainActor.run { isGeneratingTryOn = false; tryOnMessage = "Please select only 1 pair of shoes." }; return }
        if !fullBodyItems.isEmpty {
            if !bottoms.isEmpty { await MainActor.run { isGeneratingTryOn = false; tryOnMessage = "You cannot wear a Dress and Bottoms together." }; return }
            if fullBodyItems.count > 1 { await MainActor.run { isGeneratingTryOn = false; tryOnMessage = "Please select only 1 Full-Body outfit." }; return }
        }
        if fullBodyItems.isEmpty && bottoms.count > 1 { await MainActor.run { isGeneratingTryOn = false; tryOnMessage = "Please select only 1 Bottom." }; return }
        if tops.count > 2 { await MainActor.run { isGeneratingTryOn = false; tryOnMessage = "Layering Limit: Max 2 Tops." }; return }
        
        // Fetch User Context
        guard let email = effectiveEmail else { return }
        
        do {
            let userDoc = try await db.collection("users").document(email).getDocument()
            let userData = userDoc.data()
            
            guard let avatarURLString = userData?["avatarURL"] as? String,
                  let avatarURL = URL(string: avatarURLString) else {
                await MainActor.run { isGeneratingTryOn = false; tryOnMessage = "Avatar not found." }
                return
            }
            
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
    
    // MARK: - 3. Add Item Logic (Manual & Smart Scan)
    
    /// Saves a Manually Added item
    func saveManualItem(image: UIImage, category: ClothingCategory, subCategory: String, size: String) async {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        
        await MainActor.run { isUploading = true }
        
        do {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
            let fileName = "\(UUID().uuidString).jpg"
            let storageRef = storage.reference().child("clothes/\(fileName)")
            
            _ = try await storageRef.putDataAsync(imageData)
            let downloadURL = try await storageRef.downloadURL()
            
            try await db.collection("clothes").addDocument(data: [
                "imageURL": downloadURL.absoluteString,
                "ownerEmail": userEmail,
                "category": category.rawValue,
                "subcategory": subCategory,
                "size": size,
                "createdat": FieldValue.serverTimestamp()
            ])
            
            await MainActor.run { isUploading = false }
        } catch {
            print("Error saving item: \(error.localizedDescription)")
            await MainActor.run { isUploading = false }
        }
    }
    
    /// RESTORED: Saves an Auto-Measured item (LiDAR / Smart Scan)
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
                "category": category, // String from Smart Sheet
                "subcategory": subCategory,
                "size": size,
                "measurements": ["width": width, "length": length], // Store raw data
                "isAutoMeasured": true,
                "createdat": FieldValue.serverTimestamp()
            ])
            
            await MainActor.run { isUploading = false }
            print("Smart item saved successfully.")
            
        } catch {
            print("Error saving smart item: \(error.localizedDescription)")
            await MainActor.run { isUploading = false }
        }
    }
    
    /// RESTORED: Logic to determine size from measurements
    func determineSizeFromAutoMeasurements(width: Double, length: Double, category: String, subCategory: String) async -> String {
        // Heuristic Algorithm
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
    
    func updateItemSize(_ item: ClothingItem, newSize: String) {
        db.collection("clothes").document(item.id).updateData(["size": newSize])
    }
    
    func deleteItem(_ item: ClothingItem) {
        // 1. UI Optimistic Update
        DispatchQueue.main.async {
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
    
    /// Deletes a look from history with Instant UI Refresh
    func deleteLook(_ look: SavedLook) {
        // 1. Optimistic UI Update
        DispatchQueue.main.async {
            withAnimation {
                self.savedLooks.removeAll { $0.id == look.id }
            }
        }
        
        // 2. Clear Cache
        ImageCache.default.removeImage(forKey: look.imageURL)
        
        // 3. Delete from DB
        db.collection("generated_looks").document(look.id).delete()
        
        // 4. Delete from Storage
        storage.reference(forURL: look.imageURL).delete { _ in }
    }
    
    /// Saves current look with Instant UI Refresh
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
            let urlString = downloadURL.absoluteString
            let timestamp = Date()
            
            // Optimistic UI Update
            let newLook = SavedLook(id: customDocID, imageURL: urlString, date: timestamp, itemsUsed: currentItemsUsed)
            await MainActor.run {
                withAnimation { self.savedLooks.insert(newLook, at: 0) }
            }
            
            try await db.collection("generated_looks").document(customDocID).setData([
                "imageURL": urlString,
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
// MARK: - Image Validation (Strict Mode)
/// Validates if an image contains clothing.
    /// Returns FALSE if the image contains nature, vehicles, or food.
    func validateImageIsClothing(_ image: UIImage) async -> Bool {
        guard let cgImage = image.cgImage else { return false }
        
        return await Task.detached(priority: .userInitiated) {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            // Helper to store result safely
            var isClothing = false
            
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    print("Vision Error: \(error.localizedDescription)")
                    return
                }
                
                guard let results = request.results as? [VNClassificationObservation] else { return }
                
                // 1. GET TOP RESULTS
                // We check the top 3 items the AI is most confident about.
                let topResults = results.prefix(3)
                
                // 🔍 DEBUG PRINT: Look at your Xcode Console to see this!
                let observationString = topResults.map { "\($0.identifier) (\(Int($0.confidence * 100))%)" }.joined(separator: ", ")
                print("🤖 Vision sees: [\(observationString)]")
                
                // 2. BLACKLIST (Immediate Fail)
                // If any of the top results match these, BLOCK IT immediately.
                let blacklist = [
                    "tree", "plant", "flower", "grass", "nature", "forest",
                    "vehicle", "car", "truck", "bicycle", "wheel",
                    "food", "dish", "vegetable", "fruit", "meat",
                    "animal", "dog", "cat", "bird",
                    "building", "room", "furniture"
                ]
                
                for result in topResults {
                    if blacklist.contains(where: { result.identifier.lowercased().contains($0) }) {
                        print("⛔️ Blocked: Detected '\(result.identifier)' which is in the blacklist.")
                        isClothing = false
                        return
                    }
                }
                
                // 3. WHITELIST (Required Match)
                // The image MUST match one of these to pass.
                let whitelist = [
                    "clothing", "apparel", "shirt", "blouse", "top", "t-shirt", "sweatshirt", "hoodie",
                    "pants", "trousers", "jeans", "shorts", "skirt", "leggings",
                    "dress", "gown", "robe", "jumpsuit",
                    "jacket", "coat", "blazer", "sweater", "cardigan", "vest", "suit",
                    "shoe", "sneaker", "boot", "sandal", "heel", "loafer", "footwear",
                    "hat", "cap", "bag", "purse", "accessory", "jersey", "uniform"
                ]
                
                isClothing = topResults.contains { observation in
                    let id = observation.identifier.lowercased()
                    return whitelist.contains { id.contains($0) }
                }
                
                if isClothing {
                    print("✅ Validated as Clothing.")
                } else {
                    print("⚠️ Failed Validation: No clothing keywords found in top results.")
                }
            }
            
            do {
                try handler.perform([request])
                return isClothing
            } catch {
                print("Vision Critical Error: \(error.localizedDescription)")
                
                // SIMULATOR HANDLING:
                // If you are on the Simulator, Vision often fails with "Espresso Error".
                // We allow it on Simulator so you can keep coding, but on a Real Device, this fails.
                #if targetEnvironment(simulator)
                print("⚠️ Simulator detected: Allowing image bypass (Vision hardware unavailable).")
                return true
                #else
                return false // Strict fail on real devices
                #endif
            }
        }.value
    }
}

