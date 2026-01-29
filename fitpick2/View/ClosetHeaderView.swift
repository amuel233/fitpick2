import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ClosetHeaderView: View {
    @StateObject private var bodyVM = BodyMeasurementViewModel()
    @State private var avatarURL: String? = nil
    private let db = Firestore.firestore()
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let urlString = avatarURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure:
                                defaultPlaceholder
                            case .empty:
                                ProgressView()
                            @unknown default:
                                defaultPlaceholder
                            }
                        }
                    } else {
                        defaultPlaceholder
                    }
                }
                .frame(width: 360, height: 350)
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 10)
                
                // 2. AI GENERATE BUTTON (Floating)
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
                .offset(x: 10, y: 10) // Let it hang slightly off the edge
            }
            .padding(.top, 10)
            
            // 3. CAPTION
            VStack(spacing: 4) {
                Text("Virtual Mirror")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Generated from your body specs")
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


#Preview {
    ClosetHeaderView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
