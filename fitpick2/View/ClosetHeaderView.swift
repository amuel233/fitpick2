//
//  ClosetHeaderView.swift
//  fitpick
//
//  Created by Bryan Gavino on 1/20/26.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Kingfisher // Required for History Grid

struct ClosetHeaderView: View {
    // MARK: - Properties
    
    // We observe the ViewModel to get updates on History and Saved status
    @ObservedObject var viewModel: ClosetViewModel
    
    // ViewModel for Avatar Generation (Still needed locally for the "Generate Avatar" button)
    @StateObject private var bodyVM = BodyMeasurementViewModel()
    @State private var avatarURL: String? = nil
    
    // Bindings for displaying the current image (passed from Parent)
    @Binding var tryOnImage: UIImage?
    @Binding var tryOnMessage: String?
    
    // Actions passed from Parent
    var onSave: (() -> Void)?
    var isSaving: Bool = false
    var isSaved: Bool = false
    
    // Flags
    var isGuest: Bool = false
    
    // Local UI State
    @State private var showZoomedImage = false
    @State private var showHistorySheet = false // Controls the History Screen
    
    private let db = Firestore.firestore()
    
    var body: some View {
        VStack(spacing: 15) {
            ZStack(alignment: .topTrailing) {
                
                // MARK: - Image Display Container
                ZStack {
                    Color.white // Matches the AI's white background for seamless look
                    
                    if viewModel.isRestoringLook {
                        // Loading state when restoring from history
                        ProgressView("Loading...")
                    } else if let tryOn = tryOnImage {
                        // The AI Result
                        Image(uiImage: tryOn)
                            .resizable()
                            .scaledToFit()
                            .padding(.all, 4)
                    } else if let message = tryOnMessage {
                        // Error/Status Message
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle).foregroundColor(.orange)
                            Text(message).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                        }
                        .padding()
                    } else if let urlString = avatarURL, let url = URL(string: urlString) {
                        // The Base Avatar
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFit().padding(4)
                            default: defaultPlaceholder
                            }
                        }
                    } else {
                        // Fallback
                        defaultPlaceholder
                    }
                }
                .frame(width: 340, height: 350)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 15, x: 0, y: 10)
                .onLongPressGesture {
                    // Zoom trigger
                    if tryOnImage != nil || avatarURL != nil {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        showZoomedImage = true
                    }
                }
                
                // MARK: - Floating Buttons (Top Right Stack)
                VStack(spacing: 12) {
                    
                    // 1. SAVE BUTTON (Only if we have a generated image)
                    if tryOnImage != nil && !isGuest {
                        Button(action: { if !isSaved { onSave?() } }) {
                            Circle().fill(isSaved ? Color.green : Color.white).frame(width: 40, height: 40)
                                .overlay(saveButtonIcon).shadow(radius: 4)
                        }.disabled(isSaving || isSaved)
                    }
                    
                    // 2. HISTORY BUTTON (New!)
                    // Show if logged in and not currently generating
                    if !isGuest && !viewModel.isGeneratingTryOn {
                        Button(action: { showHistorySheet = true }) {
                            Circle().fill(Color.white).frame(width: 40, height: 40)
                                .overlay(Image(systemName: "clock.arrow.circlepath").foregroundColor(.blue))
                                .shadow(radius: 4)
                        }
                    }
                    
                    // 3. CLOSE/CLEAR BUTTON
                    // Shows if there is an image or error message to clear
                    if tryOnImage != nil || tryOnMessage != nil {
                        Button(action: {
                            withAnimation {
                                tryOnImage = nil
                                tryOnMessage = nil
                                viewModel.isSaved = false // Reset save state
                            }
                        }) {
                            Circle().fill(.ultraThinMaterial).frame(width: 40, height: 40)
                                .overlay(Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundColor(.primary)).shadow(radius: 4)
                        }
                    }
                    
                    // 4. GENERATE AVATAR BUTTON
                    // Only show if no image is present (empty state)
                    if !isGuest && tryOnImage == nil && tryOnMessage == nil {
                        Button(action: { Task { await bodyVM.generateAndSaveAvatar() } }) {
                            Circle().fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 40, height: 40).overlay(generateButtonIcon).shadow(radius: 4)
                        }.disabled(bodyVM.isGenerating)
                    }
                }
                .padding(12)
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .onAppear { fetchAvatarURL() }
        
        // --- SHEETS & OVERLAYS ---
        
        // Full Screen Zoom
        .fullScreenCover(isPresented: $showZoomedImage) {
            HeaderZoomView(image: tryOnImage, imageURL: avatarURL, onDismiss: { showZoomedImage = false })
        }
        
        // History List Sheet
        .sheet(isPresented: $showHistorySheet) {
            HistorySheetView(viewModel: viewModel, isPresented: $showHistorySheet)
        }
    }
    
    // MARK: - Helper Views & Functions
    
    private var saveButtonIcon: some View { Group { if isSaving { ProgressView() } else if isSaved { Image(systemName: "checkmark").foregroundColor(.white) } else { Image(systemName: "arrow.down.to.line").foregroundColor(.primary) } } }
    
    private var generateButtonIcon: some View { Group { if bodyVM.isGenerating { ProgressView().tint(.white) } else { Image(systemName: "sparkles").foregroundColor(.white) } } }
    
    private var defaultPlaceholder: some View { VStack(spacing: 12) { Image(systemName: "figure.arms.open").font(.system(size: 60)); Text("No Avatar Yet").font(.caption) }.foregroundColor(.gray.opacity(0.6)) }
    
    private func fetchAvatarURL() { guard let userEmail = Auth.auth().currentUser?.email else { return }; db.collection("users").document(userEmail).addSnapshotListener { documentSnapshot, _ in if let document = documentSnapshot, document.exists { self.avatarURL = document.data()?["avatarURL"] as? String } } }
}

// MARK: - History Sheet View (The Grid)

struct HistorySheetView: View {
    @ObservedObject var viewModel: ClosetViewModel
    @Binding var isPresented: Bool
    
    // 3 Column Grid
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.savedLooks.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "clock").font(.system(size: 50)).foregroundColor(.gray)
                        Text("No saved looks yet").font(.headline).foregroundColor(.gray)
                    }
                    .padding(.top, 100)
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(viewModel.savedLooks) { look in
                            ZStack(alignment: .topTrailing) {
                                // 1. The Image (Kingfisher for caching)
                                KFImage(URL(string: look.imageURL))
                                    .placeholder { Color.gray.opacity(0.1) }
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .onTapGesture {
                                        // 2. Restore Action
                                        Task {
                                            await viewModel.restoreLook(look)
                                            isPresented = false // Close sheet
                                        }
                                    }
                                
                                // 3. Delete Menu (Top Right Dot)
                                Menu {
                                    Button("Delete", role: .destructive) {
                                        viewModel.deleteLook(look)
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle.fill")
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.black.opacity(0.3))
                                        .clipShape(Circle())
                                }
                                .padding(4)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Look History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
        }
    }
}

// MARK: - Zoom View (Standard)

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
            Color(uiColor: .systemGroupedBackground).edgesIgnoringSafeArea(.all).onTapGesture { onDismiss() }
            GeometryReader { geometry in
                ZStack {
                    if let img = image { Image(uiImage: img).resizable().scaledToFit().frame(width: geometry.size.width, height: geometry.size.height) }
                    else if let urlStr = imageURL, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image): image.resizable().scaledToFit().frame(width: geometry.size.width, height: geometry.size.height)
                            case .failure: Image(systemName: "photo").foregroundColor(.gray)
                            case .empty: ProgressView().tint(.gray)
                            @unknown default: EmptyView()
                            }
                        }
                    }
                }
                .scaleEffect(scale).offset(offset)
                .gesture(MagnificationGesture().onChanged { val in let delta = val / lastScale; lastScale = val; scale = max(1.0, scale * delta) }.onEnded { _ in lastScale = 1.0; withAnimation { if scale < 1.0 { scale = 1.0; offset = .zero } } })
                .gesture(DragGesture().onChanged { val in if scale > 1.0 { offset = CGSize(width: lastOffset.width + val.translation.width, height: lastOffset.height + val.translation.height) } }.onEnded { _ in if scale > 1.0 { lastOffset = offset } })
            }
            VStack { HStack { Spacer(); Button(action: onDismiss) { Image(systemName: "xmark.circle.fill").font(.system(size: 30)).foregroundColor(.gray).padding().padding(.top, 40) } }; Spacer() }
        }
    }
}
