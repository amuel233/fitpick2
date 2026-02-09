//
//  ClosetHeaderView.swift
//  fitpick
//
//  Created by Bryan Gavino on 1/20/26.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ClosetHeaderView: View {
    // ViewModel for Avatar Generation
    @StateObject private var bodyVM = BodyMeasurementViewModel()
    @State private var avatarURL: String? = nil
    
    // Bindings
    @Binding var tryOnImage: UIImage?
    @Binding var tryOnMessage: String?
    
    // Save Logic
    var onSave: (() -> Void)?
    var isSaving: Bool = false
    var isSaved: Bool = false
    
    // Property to distinguish owner vs guest
    var isGuest: Bool = false
    
    private let db = Firestore.firestore()
    
    var body: some View {
        VStack(spacing: 15) {
            // Button alignment: Top Right
            ZStack(alignment: .topTrailing) {
                
                // --- IMAGE HOLDER ---
                ZStack {
                    Color.secondary.opacity(0.05)
                    
                    if let tryOn = tryOnImage {
                        Image(uiImage: tryOn)
                            .resizable()
                            .scaledToFit()
                            .padding(4)
                    } else if let message = tryOnMessage {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle).foregroundColor(.orange)
                            Text(message).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                        }
                        .padding()
                    } else if let urlString = avatarURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill().padding(4)
                            default: defaultPlaceholder
                            }
                        }
                    } else {
                        defaultPlaceholder
                    }
                }
                // CHANGED: Height reduced from 420 to 350
                .frame(width: 340, height: 350)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 10)
                
                // --- FLOATING BUTTONS (Top Right) ---
                VStack(spacing: 12) {
                    
                    // 1. SAVE BUTTON (Only show if NOT a guest)
                    if tryOnImage != nil && !isGuest {
                        Button(action: { if !isSaved { onSave?() } }) {
                            Circle()
                                .fill(isSaved ? Color.green : Color.white)
                                .frame(width: 40, height: 40)
                                .overlay(saveButtonIcon)
                                .shadow(radius: 4)
                        }
                        .disabled(isSaving || isSaved)
                    }
                    
                    // 2. CLOSE BUTTON
                    if tryOnImage != nil || tryOnMessage != nil {
                        Button(action: {
                            withAnimation {
                                tryOnImage = nil
                                tryOnMessage = nil
                            }
                        }) {
                            Circle().fill(.ultraThinMaterial).frame(width: 40, height: 40)
                                .overlay(Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundColor(.primary))
                                .shadow(radius: 4)
                        }
                    }
                    
                    // 3. GENERATE BUTTON (HIDDEN FOR GUESTS)
                    if !isGuest && tryOnImage == nil && tryOnMessage == nil {
                        Button(action: { Task { await bodyVM.generateAndSaveAvatar() } }) {
                            Circle()
                                .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 40, height: 40)
                                .overlay(generateButtonIcon)
                                .shadow(radius: 4)
                        }
                        .disabled(bodyVM.isGenerating)
                    }
                }
                .padding(12)
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .onAppear { fetchAvatarURL() }
    }
    
    // Helper for icons to keep body clean
    private var saveButtonIcon: some View {
        Group {
            if isSaving { ProgressView() }
            else if isSaved { Image(systemName: "checkmark").foregroundColor(.white) }
            else { Image(systemName: "arrow.down.to.line").foregroundColor(.primary) }
        }
    }

    private var generateButtonIcon: some View {
        Group {
            if bodyVM.isGenerating { ProgressView().tint(.white) }
            else { Image(systemName: "sparkles").foregroundColor(.white) }
        }
    }
    
    private var defaultPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.arms.open").font(.system(size: 60))
            Text("No Avatar Yet").font(.caption)
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
