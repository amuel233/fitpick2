import SwiftUI
import FirebaseStorage
import FirebaseFirestore
import FirebaseAILogic
import FirebaseAuth

class BodyMeasurementViewModel: ObservableObject {
    @Published var isGenerating: Bool = false
    @Published var generatedImage: UIImage? = nil
    
    // ✅ ADDED THIS PROPERTY TO FIX THE ERROR
    @Published var userAvatarURL: String? = nil
    
    // --- NEW VALIDATION STATES ---
    @Published var usernameError: String? = nil
    @Published var isCheckingUsername: Bool = false
    
    // Measurement Properties (Source of Truth)
    @Published var username: String = ""
    @Published var gender: String? = nil
    @Published var height: Double = 0
    @Published var bodyWeight: Double = 0
    @Published var chest: Double = 0
    @Published var shoulderWidth: Double = 0
    @Published var armLength: Double = 0
    @Published var waist: Double = 0
    @Published var hips: Double = 0
    @Published var inseam: Double = 0
    @Published var shoeSize: Double = 0
    
    @Published var bodyBase: String = ""
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    @Published private var lastGeneratedState: [String: Any] = [:]
    
    // --- NEW UNIQUE CHECK LOGIC ---
    func isUsernameUnique() async -> Bool {
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard let currentUserEmail = Auth.auth().currentUser?.email else { return false }
        
        await MainActor.run {
            isCheckingUsername = true
            usernameError = nil
        }
        
        do {
            // Check if any user already has this username
            let query = db.collection("users").whereField("username", isEqualTo: username)
            let snapshot = try await query.getDocuments()
            
            // If documents exist, check if they belong to someone else
            let isTaken = snapshot.documents.contains { $0.documentID != currentUserEmail }
            
            await MainActor.run {
                isCheckingUsername = false
                if isTaken {
                    self.usernameError = "This username is unavailable. Please try another."
                }
            }
            return !isTaken
        } catch {
            await MainActor.run { isCheckingUsername = false }
            return false
        }
    }
    
    var hasChanges: Bool {
        let current: [String: Any] = [
            "gender": gender as Any,
            "height": height,
            "bodyWeight": bodyWeight,
            "chest": chest,
            "shoulderWidth": shoulderWidth,
            "armLength": armLength,
            "waist": waist,
            "hips": hips,
            "inseam": inseam,
            "shoeSize": shoeSize
        ]
        return NSDictionary(dictionary: current).isEqual(to: lastGeneratedState) == false
    }
    
    func fetchUserData() {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        
        db.collection("users").document(userEmail).getDocument { [weak self] document, error in
            guard let self = self, let data = document?.data(), document?.exists == true else { return }
            
            DispatchQueue.main.async {
                self.usernameError = nil // Reset error on fetch
                self.username = data["username"] as? String ?? ""
                self.gender = data["gender"] as? String
                
                if let measurements = data["measurements"] as? [String: Any] {
                    self.height = measurements["height"] as? Double ?? 0
                    self.bodyWeight = measurements["bodyWeight"] as? Double ?? 0
                    self.chest = measurements["chest"] as? Double ?? 0
                    self.shoulderWidth = measurements["shoulderWidth"] as? Double ?? 0
                    self.armLength = measurements["armLength"] as? Double ?? 0
                    self.waist = measurements["waist"] as? Double ?? 0
                    self.hips = measurements["hips"] as? Double ?? 0
                    self.inseam = measurements["inseam"] as? Double ?? 0
                    self.shoeSize = measurements["shoeSize"] as? Double ?? 0
                }
                self.bodyBase = data["bodybase"] as? String ?? "average"
            }
        }
    }

    
    func generateAndSaveAvatar() async {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        await MainActor.run { isGenerating = true }
        
        do {
            let userDoc = try await db.collection("users").document(userEmail).getDocument()
            let data = userDoc.data() ?? [:]
            
            // 1. Get URLs
            let fsGender = data["gender"] as? String ?? "Male"
            let selfieURLString = data["selfie"] as? String ?? ""
            let bodyBaseURLString = data["bodybase"] as? String ?? ""
            
            
            
            // 2. Download UIImages (Matching your selfie implementation)
            var selfieUIImage: UIImage? = nil
            if !selfieURLString.isEmpty, let selfieURL = URL(string: selfieURLString) {
                if let (imageData, _) = try? await URLSession.shared.data(from: selfieURL) {
                    selfieUIImage = UIImage(data: imageData)
                }
            }
            
            let genderTerm = fsGender.uppercased()
                    let attire = fsGender.lowercased() == "female"
                        ? "female-cut sleeveless compression top and high-waisted athletic shorts"
                        : "male-cut sleeveless compression tank and athletic shorts"
            
            
            var bodyBaseUIImage: UIImage? = nil
            if !bodyBaseURLString.isEmpty, let bodyBaseURL = URL(string: bodyBaseURLString) {
                if let (imageData, _) = try? await URLSession.shared.data(from: bodyBaseURL) {
                    bodyBaseUIImage = UIImage(data: imageData)
                }
            }

            let generativeModel = FirebaseAI.firebaseAI(backend: .vertexAI(location: "us-central1")).generativeModel(
                modelName: "gemini-2.5-flash-image"
            )
            
            
            // 3. Vision-Focused Prompt
            let prompt = """
                [SYSTEM ROLE]: EXPERT BIOMETRIC ANATOMIST.
                [TARGET BIOLOGY]: Biological \(genderTerm)
                
                [VISUAL FIDELITY MANDATE]:
                - CONDITIONAL BLUEPRINT: IF 'BodyBase' is provided, use it as the absolute skeletal and muscular blueprint. Replicate the user's specific limb-to-torso ratio and bone structure exactly as seen in the image. 
                    - DE-STYLING: Strictly disregard and remove all clothing, accessories, jewelry, tattoos, or skin markings present in 'BodyBase'. Extract only the raw physical volume and bone structure.
                - ABSENCE OF BASE: If 'BodyBase' is not provided, generate a physiologically accurate \(genderTerm) figure based strictly on the [CORE MEASUREMENTS] below.
                - GENDER RECOGNITION: The avatar must be clearly identifiable as a \(genderTerm) individual. If 'Selfie' is provided, use it for 100% facial identity; otherwise, use a consistent \(genderTerm) face.
                - CONDITIONAL BLUEPRINT: IF 'BodyBase' is provided, use it as the absolute skeletal and muscular blueprint. Replicate the user's specific limb-to-torso ratio and bone structure exactly as seen in the image. 
                - ABSENCE OF BASE: If 'BodyBase' is not provided, generate a physiologically accurate \(genderTerm) figure based strictly on the [CORE MEASUREMENTS] below.
                
                [CORE MEASUREMENTS]:
                - Stature: \(height)cm (Scale the 'BodyBase' to this exact vertical height).
                - Mass: \(bodyWeight)kg (Distribute volume according to the 'BodyBase' contours).
                - Torso Geometry: Waist \(waist)cm and Hips \(hips)cm. Use these as the primary horizontal constraints.
                - Limbs: Inseam \(inseam)cm, Arm Length \(armLength)cm, Shoulder Width \(shoulderWidth)cm.
                
                [MANDATORY COMPOSITION]:
                - HEAD-TO-TOE ALIGNMENT: Top of head (crown) must be positioned at the top of the image frame; feet must be positioned at the bottom of the image frame.
                - NO ROTATION: 0-degree rotation is mandatory. Do not tilt, rotate, or use landscape/horizontal orientation. 
                - STANDING: Neutral A-pose (arms slightly away from sides, legs straight).
                - ATTIRE: \(attire) in matte charcoal. Ensure fabric is ultra-tight to show the \(genderTerm) silhouette.

                [IMAGE QUALITY]:
                - CAMERA: Eye-level, perfectly centered, long-shot. No "Dutch angle" or tilt.
                - BACKGROUND: Solid, high-contrast white studio. 
                - FULL FRAME: Render the entire body within the vertical bounds. DO NOT CROP THE HEAD AND THE FEET.
                """
            
            let response: GenerateContentResponse
                    
                    // Logic to handle different combinations of available images
                    if let selfie = selfieUIImage, let bodyBase = bodyBaseUIImage {
                        response = try await generativeModel.generateContent(prompt, selfie, bodyBase)
                    } else if let bodyBase = bodyBaseUIImage {
                        response = try await generativeModel.generateContent(prompt, bodyBase)
                    } else if let selfie = selfieUIImage {
                        response = try await generativeModel.generateContent(prompt, selfie)
                    } else {
                        response = try await generativeModel.generateContent(prompt)
                    }
            
            
            guard let generatedData = response.inlineDataParts.first?.data,
                          let generatedUIImage = UIImage(data: generatedData) else { return }
            
            let storageRef = storage.reference().child("avatars/\(userEmail)_avatar.jpg")
            _ = try await storageRef.putDataAsync(generatedData)
            let downloadURL = try await storageRef.downloadURL()
            
            try await db.collection("users").document(userEmail).updateData([
                "avatarURL": downloadURL.absoluteString
            ])
            
            await MainActor.run {
                self.generatedImage = generatedUIImage
                self.isGenerating = false
            }
        } catch {
            print("Avatar Generation Error: \(error.localizedDescription)")
            await MainActor.run { isGenerating = false }
        }
    }
}

