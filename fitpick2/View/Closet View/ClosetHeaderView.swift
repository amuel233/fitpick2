//
//  ClosetHeaderView.swift
//  fitpick
//
//  Created by FitPick on 2/13/26.
//

import SwiftUI
import Kingfisher

struct ClosetHeaderView: View {
    @ObservedObject var viewModel: ClosetViewModel
    
    // ViewModel for Avatar Generation logic
    @StateObject private var bodyVM = BodyMeasurementViewModel()
    
    // Bindings for Try-On
    @Binding var tryOnImage: UIImage?
    @Binding var tryOnMessage: String?
    
    // Actions
    var onSave: (() -> Void)?
    var isSaving: Bool = false
    var isSaved: Bool = false
    var isGuest: Bool = false
    
    // UI State
    @State private var showZoomedImage = false
    @State private var showHistorySheet = false
    
    var body: some View {
        VStack(spacing: 15) {
            ZStack(alignment: .topTrailing) {
                
                // MARK: - MAIN DISPLAY AREA
                ZStack {
                    Color.white // Background
                    
                    if viewModel.isRestoringLook {
                        // A. Loading History
                        VStack(spacing: 10) {
                            ProgressView()
                            Text("Restoring Look...").font(.caption).foregroundColor(.gray)
                        }
                        
                    } else if let tryOn = tryOnImage {
                        // B. Try-On Result (Generated Look)
                        Image(uiImage: tryOn)
                            .resizable()
                            .scaledToFit()
                        
                    } else if let message = tryOnMessage {
                        // C. Error Message
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle).foregroundColor(.orange)
                            Text(message)
                                .font(.caption).foregroundColor(.secondary)
                                .multilineTextAlignment(.center).padding()
                        }
                        
                    } else if let urlString = viewModel.userAvatarURL, let url = URL(string: urlString) {
                        // D. DYNAMIC AVATAR (Cached & Listening)
                        KFImage(url)
                            .placeholder {
                                ProgressView() // Spinner while downloading
                            }
                            .cacheMemoryOnly()
                            .diskCacheExpiration(.days(7)) // Offline Support
                            .fade(duration: 0.25)
                            .resizable()
                            .scaledToFit()
                            .onTapGesture {
                                // Tap avatar to zoom
                                showZoomedImage = true
                            }
                        
                    } else {
                        // E. PROMPT (No Avatar Found)
                        // Shows a call-to-action to generate one
                        Button(action: {
                            Task { await bodyVM.generateAndSaveAvatar() }
                        }) {
                            VStack(spacing: 12) {
                                if bodyVM.isGenerating {
                                    ProgressView()
                                    Text("Creating your twin...").font(.caption).foregroundColor(.blue)
                                } else {
                                    Image(systemName: "sparkles.rectangle.stack")
                                        .font(.system(size: 50))
                                        .foregroundColor(.blue.opacity(0.6))
                                    
                                    Text("Tap to Generate Avatar")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text("Create a digital twin for virtual try-ons")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.gray.opacity(0.05))
                        }
                        .disabled(bodyVM.isGenerating)
                    }
                }
                // --- CARD STYLING ---
                .frame(width: 340, height: 350)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 10)
                
    // MARK: - FLOATING CONTROLS (Top Right)
                    // Only show these if we have content OR an avatar exists
                    if tryOnImage != nil || viewModel.userAvatarURL != nil {
                        VStack(spacing: 12) {
                            
                            // 1. SAVE LOOK (Only when a new Try-On is visible)
                            if tryOnImage != nil && !isGuest {
                                Button(action: { if !isSaved { onSave?() } }) {
                                    CircleButton(
                                        icon: isSaved ? "checkmark" : "arrow.down.to.line",
                                        color: isSaved ? .green : .primary,
                                        isLoading: isSaving
                                    )
                                }
                                .disabled(isSaving || isSaved)
                            }
                            
                            // 2. SAVED LOOKS / GALLERY (Replaced Clock with Photo Stack)
                            if !isGuest && !viewModel.isGeneratingTryOn {
                                Button(action: { showHistorySheet = true }) {
                                    // "photo.stack" looks like a Gallery/Lookbook
                                    CircleButton(icon: "photo.stack", color: .blue)
                                }
                            }
                            
                            // 3. CLOSE / RESET (Only when viewing a Try-On)
                            if tryOnImage != nil || tryOnMessage != nil {
                                Button(action: {
                                    withAnimation {
                                        tryOnImage = nil
                                        tryOnMessage = nil
                                        viewModel.isSaved = false
                                    }
                                }) {
                                    CircleButton(icon: "xmark", color: .secondary)
                                }
                            }
                            
                            // 4. UPDATE AVATAR (Small Sparkles)
                            // Only show if we are NOT viewing a Try-On, but we HAVE an avatar.
                            // This allows the user to "Re-roll" or update their digital twin.
                            if !isGuest && tryOnImage == nil && viewModel.userAvatarURL != nil {
                                Button(action: { Task { await bodyVM.generateAndSaveAvatar() } }) {
                                    Group {
                                        if bodyVM.isGenerating {
                                            ProgressView().tint(.white)
                                        } else {
                                            Image(systemName: "sparkles").foregroundColor(.white)
                                        }
                                    }
                                    .frame(width: 40, height: 40)
                                    .background(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                                }
                                .disabled(bodyVM.isGenerating)
                            }
                        }
                        .padding(12)
                    }
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .fullScreenCover(isPresented: $showZoomedImage) {
            HeaderZoomView(image: tryOnImage, imageURL: viewModel.userAvatarURL, onDismiss: { showZoomedImage = false })
        }
        .sheet(isPresented: $showHistorySheet) {
            HistorySheetView(viewModel: viewModel, isPresented: $showHistorySheet)
        }
    }
}

// Helper for consistent buttons
struct CircleButton: View {
    let icon: String
    let color: Color
    var isLoading: Bool = false
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 40, height: 40)
            .overlay(
                Group {
                    if isLoading { ProgressView() }
                    else { Image(systemName: icon).foregroundColor(color) }
                }
            )
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Helper Views

struct HeaderZoomView: View {
    let image: UIImage?
    let imageURL: String? // Changed to String? to match ViewModel
    let onDismiss: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            // Dark Background
            Color.black.edgesIgnoringSafeArea(.all)
                .onTapGesture { onDismiss() }
            
            GeometryReader { geometry in
                ZStack {
                    if let img = image {
                        // 1. Local Try-On Image
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    } else if let urlStr = imageURL, let url = URL(string: urlStr) {
                        // 2. Remote Avatar Image (Cached)
                        KFImage(url)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
                .scaleEffect(scale)
                .offset(offset)
                // Zoom Gestures
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
                // Pan Gestures
                .gesture(
                    DragGesture()
                        .onChanged { val in
                            if scale > 1.0 {
                                offset = CGSize(
                                    width: lastOffset.width + val.translation.width,
                                    height: lastOffset.height + val.translation.height
                                )
                            }
                        }
                        .onEnded { _ in
                            if scale > 1.0 { lastOffset = offset }
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
                            .foregroundColor(.white)
                            .padding()
                            .padding(.top, 40)
                    }
                }
                Spacer()
            }
        }
    }
}

struct HistorySheetView: View {
    @ObservedObject var viewModel: ClosetViewModel
    @Binding var isPresented: Bool
    
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.savedLooks.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "clock")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No saved looks yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 100)
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(viewModel.savedLooks) { look in
                            ZStack(alignment: .topTrailing) {
                                // Cached History Image
                                KFImage(URL(string: look.imageURL))
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        Task {
                                            await viewModel.restoreLook(look)
                                            isPresented = false
                                        }
                                    }
                                
                                // Context Menu for Delete
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
