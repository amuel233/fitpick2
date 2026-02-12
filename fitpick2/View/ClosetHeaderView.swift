//
//  ClosetHeaderView.swift
//  fitpick
//
//  Created by Bryan Gavino on 1/20/26.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Kingfisher

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
    
    // Guest Mode
    var isGuest: Bool = false
    
    // Zoom State
    @State private var showZoomedImage = false
    
    private let db = Firestore.firestore()
    
    var body: some View {
        VStack(spacing: 15) {
            ZStack(alignment: .topTrailing) {
                
                // --- IMAGE HOLDER ---
                ZStack {
                    Color.secondary.opacity(0.05)
                    
                    if let tryOn = tryOnImage {
                        Image(uiImage: tryOn).resizable().scaledToFit().padding(4)
                    } else if let message = tryOnMessage {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundColor(.orange)
                            Text(message).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                        }
                        .padding()
                    } else if let urlString = avatarURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image): image.resizable().scaledToFill().padding(4)
                            default: defaultPlaceholder
                            }
                        }
                    } else {
                        defaultPlaceholder
                    }
                }
                .frame(width: 340, height: 350)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 10)
                // --- LONG PRESS TO ZOOM ---
                .onLongPressGesture {
                    if tryOnImage != nil || avatarURL != nil {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        showZoomedImage = true
                    }
                }
                
                // --- FLOATING BUTTONS ---
                VStack(spacing: 12) {
                    if tryOnImage != nil && !isGuest {
                        Button(action: { if !isSaved { onSave?() } }) {
                            Circle().fill(isSaved ? Color.green : Color.white).frame(width: 40, height: 40)
                                .overlay(saveButtonIcon).shadow(radius: 4)
                        }.disabled(isSaving || isSaved)
                    }
                    if tryOnImage != nil || tryOnMessage != nil {
                        Button(action: { withAnimation { tryOnImage = nil; tryOnMessage = nil } }) {
                            Circle().fill(.ultraThinMaterial).frame(width: 40, height: 40)
                                .overlay(Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundColor(.primary)).shadow(radius: 4)
                        }
                    }
                    if !isGuest && tryOnImage == nil && tryOnMessage == nil {
                        Button(action: { Task { await bodyVM.generateAndSaveAvatar() } }) {
                            Circle().fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 40, height: 40).overlay(generateButtonIcon).shadow(radius: 4)
                        }.disabled(bodyVM.isGenerating)
                    }
                }.padding(12)
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .onAppear { fetchAvatarURL() }
        
        // --- FULL SCREEN ZOOM OVERLAY ---
        .fullScreenCover(isPresented: $showZoomedImage) {
            HeaderZoomView(image: tryOnImage, imageURL: avatarURL, onDismiss: { showZoomedImage = false })
        }
    }
    
    // Helpers
    private var saveButtonIcon: some View { Group { if isSaving { ProgressView() } else if isSaved { Image(systemName: "checkmark").foregroundColor(.white) } else { Image(systemName: "arrow.down.to.line").foregroundColor(.primary) } } }
    private var generateButtonIcon: some View { Group { if bodyVM.isGenerating { ProgressView().tint(.white) } else { Image(systemName: "sparkles").foregroundColor(.white) } } }
    private var defaultPlaceholder: some View { VStack(spacing: 12) { Image(systemName: "figure.arms.open").font(.system(size: 60)); Text("No Avatar Yet").font(.caption) }.foregroundColor(.gray.opacity(0.6)) }
    private func fetchAvatarURL() { guard let userEmail = Auth.auth().currentUser?.email else { return }; db.collection("users").document(userEmail).addSnapshotListener { documentSnapshot, _ in if let document = documentSnapshot, document.exists { self.avatarURL = document.data()?["avatarURL"] as? String } } }
}

// --- UPDATED ZOOM VIEW ---
struct HeaderZoomView: View {
    let image: UIImage?
    let imageURL: String?
    let onDismiss: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            // FIX: Changed background from .black to systemGroupedBackground (Light Gray)
            Color(uiColor: .systemGroupedBackground)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { onDismiss() }
            
            GeometryReader { geometry in
                ZStack {
                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    } else if let urlStr = imageURL, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                            case .failure:
                                Image(systemName: "photo").foregroundColor(.gray)
                            case .empty:
                                ProgressView().tint(.gray) // Darker tint for light bg
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                }
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { val in
                            let delta = val / lastScale
                            lastScale = val
                            scale = max(1.0, scale * delta)
                        }
                        .onEnded { _ in
                            lastScale = 1.0
                            withAnimation {
                                if scale < 1.0 { scale = 1.0; offset = .zero }
                            }
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { val in
                            if scale > 1.0 {
                                offset = CGSize(width: lastOffset.width + val.translation.width, height: lastOffset.height + val.translation.height)
                            }
                        }
                        .onEnded { _ in
                            if scale > 1.0 {
                                lastOffset = offset
                            }
                        }
                )
            }
            
            // Close Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.gray) // Changed to gray for visibility
                            .padding()
                            .padding(.top, 40)
                    }
                }
                Spacer()
            }
        }
    }
}
