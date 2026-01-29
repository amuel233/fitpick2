//
//  BodyMeasurementViewModel.swift
//  fitpick2
//
//  Created by Amuel Ryco Nidoy on 1/23/26.
//

import SwiftUI
import FirebaseStorage
import FirebaseFirestore
import FirebaseAILogic
import FirebaseAuth

class BodyMeasurementViewModel: ObservableObject {
    @Published var isGenerating: Bool = false
    @Published var generatedImage: UIImage? = nil
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    func generateAndSaveAvatar() async {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        
        await MainActor.run { isGenerating = true }
        
        do {
            // 1. Fetch latest measurements from Firestore
            let userDoc = try await db.collection("users").document(userEmail).getDocument()
            let data = userDoc.data() ?? [:]
            
            let height = data["height"] as? Double ?? 170.0
            let weight = data["weight"] as? Double ?? 70.0
            let gender = data["gender"] as? String ?? "male"
            let chest = data["chest"] as? Double ?? 90.0
            let shoulderWidth = data["shoulderWidth"] as? Double ?? 45.0
            let armLength = data["armLength"] as? Double ?? 60.0
            let waist = data["waist"] as? Double ?? 80.0
            let hips = data["hips"] as? Double ?? 95.0
            let inseam = data["inseam"] as? Double ?? 80.0
            let shoeSize = data["shoeSize"] as? Double ?? 9.0
            
            // 2. Setup Generative AI
            let generativeModel = FirebaseAI.firebaseAI(backend: .vertexAI(location: "us-central1")).generativeModel(
                modelName: "gemini-2.5-flash-image"
            )
            
            // Per your instruction: One face, front-facing, neutral background
            let prompt = """
        ACT AS A 3D CHARACTER ENGINE. 
                TASK: Generate a photorealistic 3D human avatar for a virtual fitting room.
                
                CONSISTENCY RULES (MANDATORY):
                1. IDENTITY: Use the EXACT same face and ethnicity for every request. The avatar must look like the same individual every time.
                2. POSITION: The avatar must be standing perfectly centered.
                3. ORIENTATION: Always facing directly toward the camera (Front View). Do not rotate the body.
                4. POSE: Static 'A-pose' (arms slightly out, legs straight).
                
                ANATOMICAL MEASUREMENTS (ONLY THESE SHOULD CHANGE):
                - Gender: \(gender)
                - Height: \(height)cm
                - Weight: \(weight)kg
                - Shoulder Width: \(shoulderWidth)cm
                - Chest: \(chest)cm
                - Waist: \(waist)cm
                - Hips: \(hips)cm
                - Arm Length: \(armLength)cm
                - Inseam: \(inseam)cm
                - US Shoe Size: \(shoeSize)
        
        INSTRUCTIONS FOR BODY COMPOSITION:
        1. Use the Height (\(height)cm) and Weight (\(weight)kg) to accurately represent the body mass index (BMI).
        2. Adjust the thickness of the arms, legs, and neck to be proportional to a \(weight)kg frame.
        3. If the weight is high relative to the height, ensure a soft, endomorphic body type. 
        4. If the weight is low relative to height, ensure a lean, ectomorphic body type.
        5. The waist (\(waist)cm) and chest (\(chest)cm) measurements must be the primary guide for the torso silhouette.
        
        VISUAL STYLE:
                - Clean, minimalist white studio background.
                - Wearing tight, form-fitting grey athletic base-layer clothing (this is essential to see the body changes clearly).
                - 8k resolution, cinematic lighting, realistic skin texture.
                - No extra accessories or dramatic poses.
        """

            
            let response = try await generativeModel.generateContent(prompt)
            guard let imageData = response.inlineDataParts.first?.data,
                  let uiImage = UIImage(data: imageData) else { return }
            
            // 3. Upload to Firebase Storage
            let storageRef = storage.reference().child("avatars/\(userEmail).jpg")
            _ = try await storageRef.putDataAsync(imageData)
            let downloadURL = try await storageRef.downloadURL()
            
            // 4. Save URL back to Firestore
            try await db.collection("users").document(userEmail).updateData([
                "avatarURL": downloadURL.absoluteString
            ])
            
            await MainActor.run {
                self.generatedImage = uiImage
                self.isGenerating = false
            }
            
        } catch {
            print("Avatar Generation Error: \(error.localizedDescription)")
            await MainActor.run { isGenerating = false }
        }
    }
}
