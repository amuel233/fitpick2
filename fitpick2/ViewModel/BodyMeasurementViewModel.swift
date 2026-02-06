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
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    @Published private var lastGeneratedState: [String: Any] = [:]
    
    
    /// Compares current UI values against the last successfully generated avatar specs
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
    
    
    /// Fetches existing user data from Firestore to populate the UI
    func fetchUserData() {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        
        db.collection("users").document(userEmail).getDocument { [weak self] document, error in
            guard let self = self, let data = document?.data(), document?.exists == true else { return }
            
            DispatchQueue.main.async {
                // 1. Get the username
                            self.username = data["username"] as? String ?? ""
                            
                self.gender = data["gender"] as? String
                
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
            
            
            let fsGender = data["gender"] as? String ?? "Male"
            
            var selfieUIImage: UIImage? = nil
            if !selfieURLString.isEmpty, let selfieURL = URL(string: selfieURLString) {
                if let (imageData, _) = try? await URLSession.shared.data(from: selfieURL) {
                    selfieUIImage = UIImage(data: imageData)
                }
            }
            
            let generativeModel = FirebaseAI.firebaseAI(backend: .vertexAI(location: "us-central1")).generativeModel(
                modelName: "gemini-2.5-flash-image"
            )
            
            let genderTerm = fsGender.lowercased() == "female" ? "FEMALE" : "MALE"
                let anatomyFocus = fsGender.lowercased() == "female"
                    ? "feminine curves, female bust, and wider female hips"
                    : "masculine chest, broad shoulders, and male torso"
            
            
            let identityInstruction = (selfieUIImage != nil)
                ? "IDENTITY: Use the attached selfie for the face and head. The avatar must be an exact 3D likeness of this person."
                : "IDENTITY: Generate a realistic, neutral face for a \(genderTerm) consistent with the body type."
            let prompt = """
                \(identityInstruction)

                [SYSTEM ROLE]: 3D ANATOMY SPECIALIST & CHARACTER ARTIST
                [TASK]: Create a high-fidelity 3D human avatar. 
                [PRIMARY SUBJECT]: A \(genderTerm) human model.
                
                [MANDATORY ANATOMICAL DATA]:
                - The avatar MUST have a \(genderTerm) skeletal structure and \(anatomyFocus).               
                - Height: \(height)cm
                - Body Weight: \(bodyWeight)kg
                - Shoulder Width: \(shoulderWidth)cm
                - Chest Circumference: \(chest)cm
                - Waist Circumference: \(waist)cm
                - Hips Circumference: \(hips)cm
                - Arm Length: \(armLength)cm
                - Inseam: \(inseam)cm

                [FRAMING & COMPOSITION - CRITICAL]:
                1. FULL BODY SHOT: The image must show the ENTIRE body from the top of the head to the bottom of the feet. 
                2. NO CROPPING: Do not crop the head, arms, or legs. There must be empty white space above the head and below the feet.
                3. CAMERA: Eye-level, centered, wide-angle lens to capture the full vertical height of the avatar.

                [GEOMETRY ENFORCEMENT RULES]:
                1. FORCED VOLUME: The avatar MUST reflect a \(bodyTypeDescription).
                2. TORSO SHAPE: Absolute priority is the Waist-to-Chest ratio. If Waist (\(waist)cm) ≥ Chest (\(chest)cm), render a protruding abdomen and soft midsection. 
                3. PROPORTIONAL SCALE: Use the Height (\(height)cm) and Inseam (\(inseam)cm) to determine leg length. Use Weight (\(bodyWeight)kg) to determine global body volume.
                4. GENDERED SILHOUETTE: If \(genderTerm) is Female, prioritize a feminine pelvic structure and chest. If \(genderTerm) is Male, prioritize a masculine torso and shoulder structure.
                5. LIMB GIRTH: Thighs and arms must be scaled to support a \(bodyWeight)kg frame.

                [SCENE & STYLE]:
                - Pose: Static, front-facing A-pose, arms 45-degrees away from the torso, palms facing forward.
                - Clothing: Ultra-tight, skin-tight matte grey spandex base layer. No wrinkles, no loose fabric. This must act as a "second skin" to show accurate body contours.
                - Background: Pure white, minimalist infinite studio floor with a soft drop shadow under the feet for depth.
                - Render: Photorealistic, 8K resolution, high-quality 3D scan aesthetic.

                [CONSISTENCY]: 
                - Face: \(genderTerm) facial features. If a selfie is provided, map the face textures and features exactly onto the 3D head model.
                - If no selfie, maintain a consistent generic \(genderTerm) facial structure across all generations.
                - The head-to-body size ratio must be anatomically correct for a person who is \(height)cm tall.
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

