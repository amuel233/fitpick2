import SwiftUI
import FirebaseStorage
import FirebaseFirestore
import FirebaseAILogic
import FirebaseAuth

class BodyMeasurementViewModel: ObservableObject {
    @Published var isGenerating: Bool = false
    @Published var generatedImage: UIImage? = nil
    
    // Measurement Properties (Source of Truth)
    @Published var username: String = ""
    @Published var gender: String = "Male"
    @Published var height: Double = 0
    @Published var bodyWeight: Double = 0
    @Published var chest: Double = 0
    @Published var shoulderWidth: Double = 0
    @Published var armLength: Double = 0
    @Published var waist: Double = 0
    @Published var hips: Double = 0
    @Published var inseam: Double = 0
    @Published var shoeSize: Double = 0
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    /// Fetches existing user data from Firestore to populate the UI
    func fetchUserData() {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        
        db.collection("users").document(userEmail).getDocument { [weak self] document, error in
            guard let self = self, let data = document?.data(), document?.exists == true else { return }
            
            DispatchQueue.main.async {
                self.username = data["username"] as? String ?? ""
                self.gender = data["gender"] as? String ?? "Male"
                
                // Fetching from the "measurements" nested map
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
            }
        }
    }
    
    
    /// Calculates a descriptive body type based on BMI to force the AI to scale volume correctly
        var bodyTypeDescription: String {
            guard height > 0 else { return "Average build" }
            let heightInMeters = height / 100
            let bmi = bodyWeight / (heightInMeters * heightInMeters)
            
            switch bmi {
            case ..<18.5:
                return "Ectomorphic build: Very lean, slender frame, minimal body fat, narrow shoulders."
            case 18.5..<25.0:
                return "Mesomorphic build: Athletic and proportioned frame, average muscle definition."
            case 25.0..<30.0:
                return "Endomorphic build: Significant body mass, thick torso, rounded limbs, soft musculature."
            case 30.0...:
                return "Heavyset/Obese build: Pronounced abdominal volume (stomach), thick neck and thighs, heavy-set frame."
            default:
                return "Average build"
            }
        }
    
    
    
    func generateAndSaveAvatar() async {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        await MainActor.run { isGenerating = true }
        
        do {
            let userDoc = try await db.collection("users").document(userEmail).getDocument()
            let data = userDoc.data() ?? [:]
            let selfieURLString = data["selfie"] as? String ?? ""
            
            var selfieUIImage: UIImage? = nil
            if !selfieURLString.isEmpty, let selfieURL = URL(string: selfieURLString) {
                if let (imageData, _) = try? await URLSession.shared.data(from: selfieURL) {
                    selfieUIImage = UIImage(data: imageData)
                }
            }
            
            let generativeModel = FirebaseAI.firebaseAI(backend: .vertexAI(location: "us-central1")).generativeModel(
                modelName: "gemini-2.5-flash-image"
            )
            
            let identityInstruction = (selfieUIImage != nil)
                ? "IDENTITY: Use the attached selfie for the face and head. The avatar must be an exact 3D likeness of this person."
                : "IDENTITY: Generate a realistic, neutral face for a \(gender) consistent with the body type."
            let prompt = """
            \(identityInstruction)
            
            [SYSTEM ROLE]: 3D ANATOMY ENGINE
            [TASK]: Create a high-fidelity 3D human avatar. The silhouette MUST strictly match the mathematical proportions provided below.
            [MANDATORY ANATOMICAL DATA]:
            - Gender: \(gender)
            - Height: \(height)cm
            - Body Weight: \(bodyWeight)kg
            - Shoulder Width: \(shoulderWidth)cm
            - Chest Circumference: \(chest)cm
            - Waist Circumference: \(waist)cm
            - Hips Circumference: \(hips)cm
            - Arm Length: \(armLength)cm
            - Inseam: \(inseam)cm
            [GEOMETRY ENFORCEMENT RULES]:
            1. FORCED VOLUME: The avatar MUST reflect a \(bodyTypeDescription).
            2. TORSO SHAPE: The relationship between Waist (\(waist)cm) and Chest (\(chest)cm) is the absolute priority. If the waist is equal to or larger than the chest, the avatar must have a protruding stomach and a thick midsection. Do NOT render a flat stomach or "six-pack" unless the waist measurement is significantly smaller than the chest.
            3. LIMB GIRTH: Scale the thickness of the arms and legs proportionally to the total weight of \(bodyWeight)kg.
            4. FACE WEIGHT: Adjust the jawline and neck thickness to be consistent with a \(bodyWeight)kg frame.
            [SCENE & STYLE]:
            - Pose: Static, front-facing A-pose, arms slightly away from the body. Make sure that the avatar is always full body.
            - Clothing: Ultra-tight, skin-tight grey spandex base layer. This must reveal the true contours of the body without concealing weight.
            - Background: Pure white, minimalist studio.
            - Render: 8K resolution, photorealistic skin textures, soft cinematic lighting.
            [CONSISTENCY]: 
            
            - Always maintain the face from the selfie while adapting the head/neck size to fit the \(bodyWeight)kg body.
            - IDENTITY: Use the EXACT same face and ethnicity for every request. The avatar must look like the same individual every time unless there's a provided selfie of the user.
            
            """
            
            let response: GenerateContentResponse
            if let selfie = selfieUIImage {
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
