//
//  ClosetHeaderView.swift
//  fitpick
//
//  Created by Bry on 2/13/26.
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
                        .frame(height: 350) // Keep placeholder fixed height
                        
                    } else if let tryOn = tryOnImage {
                        // B. Try-On Result (Generated Look)
                        Image(uiImage: tryOn)
                            .resizable()
                            .scaledToFit()
                            .layoutPriority(1) // Tells layout to respect image size
                            .contentShape(Rectangle())
                            .onTapGesture { showZoomedImage = true }
                        
                    } else if let message = tryOnMessage {
                        // C. Error Message
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle).foregroundColor(.orange)
                            Text(message)
                                .font(.caption).foregroundColor(.secondary)
                                .multilineTextAlignment(.center).padding()
                        }
                        .frame(height: 350)
                        
                    } else if let urlString = viewModel.userAvatarURL, let url = URL(string: urlString) {
                        // D. DYNAMIC AVATAR
                        KFImage(url)
                            .placeholder {
                                ProgressView()
                                    .frame(height: 350)
                            }
                            .cacheMemoryOnly()
                            .diskCacheExpiration(.days(7))
                            .fade(duration: 0.25)
                            .resizable()
                            .scaledToFit()
                            .layoutPriority(1) // Priority ensures it dictates card height
                            .contentShape(Rectangle())
                            .onTapGesture { showZoomedImage = true }
                        
                    } else {
                        // E. PROMPT (No Avatar Found)
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
                            .frame(maxWidth: .infinity)
                            .frame(height: 350) // Force height for empty state
                            .background(Color.gray.opacity(0.05))
                        }
                        .disabled(bodyVM.isGenerating)
                    }
                }
                // --- CARD STYLING (FIXED) ---
                // We use fixed width, but flexible height (min 350)
                // This allows tall images to expand without empty bars
                .frame(width: 340)
                .frame(minHeight: 350, maxHeight: 380)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 10)
                
                // MARK: - FLOATING CONTROLS
                if tryOnImage != nil || viewModel.userAvatarURL != nil {
                    VStack(spacing: 12) {
                        
                        // 1. SAVE LOOK
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
                        
                        // 2. HISTORY
                        if !isGuest && !viewModel.isGeneratingTryOn {
                            Button(action: { showHistorySheet = true }) {
                                CircleButton(icon: "photo.stack", color: .blue)
                            }
                        }
                        
                        // 3. CLOSE
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
                        
                        // 4. UPDATE AVATAR
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
        
        // --- SHEETS ---
        .fullScreenCover(isPresented: $showZoomedImage) {
            HeaderZoomView(image: tryOnImage, imageURL: viewModel.userAvatarURL, onDismiss: { showZoomedImage = false })
        }
        .sheet(isPresented: $showHistorySheet) {
            HistorySheetView(viewModel: viewModel, isPresented: $showHistorySheet)
        }
    }
}

// MARK: - Helper Views & Subcomponents

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
            Color.black.edgesIgnoringSafeArea(.all).onTapGesture { onDismiss() }
            
            GeometryReader { geometry in
                ZStack {
                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    } else if let urlStr = imageURL, let url = URL(string: urlStr) {
                        KFImage(url)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)
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
                            withAnimation { if scale < 1.0 { scale = 1.0; offset = .zero } }
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { val in
                            if scale > 1.0 {
                                offset = CGSize(width: lastOffset.width + val.translation.width, height: lastOffset.height + val.translation.height)
                            }
                        }
                        .onEnded { _ in if scale > 1.0 { lastOffset = offset } }
                )
            }
            
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
    
    @State private var selectedLook: SavedLook?
    
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.savedLooks.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.stack")
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
                                KFImage(URL(string: look.imageURL))
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedLook = look }
                                
                                Menu {
                                    Button("Restore Look", systemImage: "arrow.counterclockwise") {
                                        Task {
                                            await viewModel.restoreLook(look)
                                            isPresented = false
                                        }
                                    }
                                    Button("Delete", systemImage: "trash", role: .destructive) {
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
            .navigationTitle("Saved Fits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
            .fullScreenCover(item: $selectedLook) { look in
                HistoryZoomView(
                    look: look,
                    viewModel: viewModel,
                    parentSheetPresented: $isPresented,
                    onDismiss: { selectedLook = nil }
                )
            }
        }
    }
}

struct HistoryZoomView: View {
    let look: SavedLook
    @ObservedObject var viewModel: ClosetViewModel
    @Binding var parentSheetPresented: Bool
    var onDismiss: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all).onTapGesture { onDismiss() }
            
            GeometryReader { geometry in
                KFImage(URL(string: look.imageURL))
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(MagnificationGesture().onChanged { val in let delta = val / lastScale; lastScale = val; scale = max(1.0, scale * delta) }.onEnded { _ in lastScale = 1.0; withAnimation { if scale < 1.0 { scale = 1.0; offset = .zero } } })
                    .gesture(DragGesture().onChanged { val in if scale > 1.0 { offset = CGSize(width: lastOffset.width + val.translation.width, height: lastOffset.height + val.translation.height) } }.onEnded { _ in if scale > 1.0 { lastOffset = offset } })
            }
            
            VStack {
                HStack { Spacer(); Button(action: onDismiss) { Image(systemName: "xmark.circle.fill").font(.system(size: 30)).foregroundColor(.white.opacity(0.8)).padding().padding(.top, 40) } }
                Spacer()
                HStack(spacing: 16) {
                    Button(action: { viewModel.deleteLook(look); onDismiss() }) { VStack(spacing: 4) { Image(systemName: "trash").font(.title3); Text("Delete").font(.caption2) }.foregroundColor(.white).frame(width: 70, height: 60).background(.ultraThinMaterial).cornerRadius(12) }
                    Button(action: { Task { await viewModel.restoreLook(look); onDismiss(); parentSheetPresented = false } }) { HStack { Image(systemName: "arrow.counterclockwise"); Text("Restore this Look") }.bold().foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 60).background(Color.blue).cornerRadius(12) }
                }
                .padding(.horizontal).padding(.bottom, 50)
            }
        }
    }
}
