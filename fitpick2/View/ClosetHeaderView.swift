import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ClosetHeaderView: View {
    // ViewModel for Avatar Generation (if needed)
    @StateObject private var bodyVM = BodyMeasurementViewModel()
    @State private var avatarURL: String? = nil
    
    // Bindings from Parent View
    @Binding var tryOnImage: UIImage?
    @Binding var tryOnMessage: String?
    
    private let db = Firestore.firestore()
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack(alignment: .bottomTrailing) {
                // IMAGE HOLDER
                ZStack {
                    // 1. Background Fill (prevents empty space looking weird)
                    Color.secondary.opacity(0.05)
                    
                    // 2. Image Logic
                    if let tryOn = tryOnImage {
                        // A. Show Generated Try-On Image (Full View)
                        Image(uiImage: tryOn)
                            .resizable()
                            .scaledToFit() // Changed from .fill to .fit
                            .padding(4)    // Add slight padding so it doesn't touch edges
                    } else if let message = tryOnMessage {
                        // B. Show Error Message
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            Text(message)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                    } else if let urlString = avatarURL, let url = URL(string: urlString) {
                        // C. Show Avatar (Full View)
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable()
                                    .scaledToFill() // Changed from .fill to .fit
                                    .padding(4)
                            case .failure:
                                defaultPlaceholder
                            case .empty:
                                ProgressView()
                            @unknown default:
                                defaultPlaceholder
                            }
                        }
                    } else {
                        // D. Placeholder
                        defaultPlaceholder
                    }
                }
                .frame(width: 360, height: 450) // Increased height slightly for full body
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 10)
                
                // FLOATING BUTTONS
                VStack(spacing: 12) {
                    // Close/Clear Try-On Button
                    if tryOnImage != nil || tryOnMessage != nil {
                        Button(action: {
                            withAnimation {
                                tryOnImage = nil
                                tryOnMessage = nil
                            }
                        }) {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "xmark")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.primary)
                                )
                                .shadow(radius: 4)
                        }
                    }
                    
                    // Generate Avatar Button (Only if not trying on)
                    if tryOnImage == nil && tryOnMessage == nil {
                        Button(action: {
                            Task {
                                await bodyVM.generateAndSaveAvatar()
                            }
                        }) {
                            Circle()
                                .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Group {
                                        if bodyVM.isGenerating {
                                            ProgressView().tint(.white)
                                        } else {
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                )
                                .shadow(radius: 4)
                        }
                        .disabled(bodyVM.isGenerating)
                    }
                }
                .offset(x: 10, y: 10)
            }
            .padding(.top, 10)
            
            // CAPTION
            VStack(spacing: 4) {
                Text(tryOnImage != nil ? "Virtual Try-On" : "Virtual Mirror")
                    .font(.title3)
                    .fontWeight(.bold)
                Text(tryOnImage != nil ? "Generated with Gemini AI" : "Generated from your body specs")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .onAppear {
            fetchAvatarURL()
        }
    }
    
    private var defaultPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.arms.open")
                .font(.system(size: 60))
            Text("No Avatar Yet")
                .font(.caption)
        }
        .foregroundColor(.gray.opacity(0.6))
    }
    
    private func fetchAvatarURL() {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        db.collection("users").document(userEmail).addSnapshotListener { documentSnapshot, _ in
            if let document = documentSnapshot, document.exists {
                self.avatarURL = document.data()?["avatarURL"] as? String
            }
        }
    }
}
