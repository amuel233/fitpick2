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
    
    // Ensure BodyMeasurementViewModel is a class conforming to ObservableObject
    @StateObject private var bodyVM = BodyMeasurementViewModel()
    
    @Binding var tryOnImage: UIImage?
    @Binding var tryOnMessage: String?
    
    var onSave: (() -> Void)?
    var onShowHistory: (() -> Void)?
    
    var isSaving: Bool = false
    var isSaved: Bool = false
    var isGuest: Bool = false
    
    @State private var showZoomedImage = false
    
    // Luxe Colors
    let luxeEcru = Color(red: 0.82, green: 0.67, blue: 0.47)
    let luxeFlax = Color(red: 0.92, green: 0.84, blue: 0.55)
    
    var body: some View {
        VStack(spacing: 15) {
            ZStack(alignment: .topTrailing) {
                
                // MARK: - MAIN DISPLAY AREA (FROSTED GLASS CARD)
                ZStack {
                    // Glass Background
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                    
                    // 1. PRIORITY: RESTORING LOOK
                    if viewModel.isRestoringLook {
                        VStack(spacing: 10) {
                            ProgressView().tint(luxeEcru)
                            Text("Restoring...").font(.caption).foregroundColor(luxeEcru)
                        }
                        .frame(height: 350)
                        
                    // 2. PRIORITY: GENERATING AVATAR (Fixes "Old Avatar Persisting" Bug)
                    } else if bodyVM.isGenerating {
                         VStack(spacing: 15) {
                             ProgressView().tint(luxeEcru)
                             VStack(spacing: 5) {
                                 Text("CREATING YOUR TWIN")
                                     .font(.headline)
                                     .fontWeight(.bold)
                                     .foregroundColor(luxeFlax)
                                     .tracking(2)
                                 Text("Analyzing biometrics...")
                                     .font(.caption)
                                     .foregroundColor(.white.opacity(0.7))
                             }
                         }
                         .frame(height: 350)
                        
                    // 3. TRY-ON RESULT
                    } else if let tryOn = tryOnImage {
                        Image(uiImage: tryOn)
                            .resizable()
                            .scaledToFill() // ✅ FIX: Fills space
                            .frame(width: 340) // Ensure frame is constrained before clipping
                            .clipped()      // ✅ FIX: Cuts off excess
                            .layoutPriority(1)
                            .onTapGesture { showZoomedImage = true }
                        
                    // 4. ERROR MESSAGE
                    } else if let message = tryOnMessage {
                        VStack {
                            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundColor(luxeEcru)
                            Text(message).font(.caption).foregroundColor(.white).multilineTextAlignment(.center)
                        }
                        .frame(height: 350)
                        
                    // 5. EXISTING AVATAR (Only shown if NOT generating)
                    } else if let urlStr = viewModel.userAvatarURL, let url = URL(string: urlStr) {
                        KFImage(url)
                            .placeholder { ProgressView().tint(luxeEcru).frame(height: 350) }
                            .resizable()
                            .scaledToFill() // ✅ FIX: Fills space (No empty top/bottom)
                            .frame(width: 340)
                            .clipped()      // ✅ FIX: Cuts off excess
                            .layoutPriority(1)
                            .onTapGesture { showZoomedImage = true }
                            .id(urlStr) // Force refresh if URL string changes
                        
                    } else {
                        // 6. EMPTY STATE (Generate Button)
                        Button(action: {
                            generateAvatar()
                        }) {
                            VStack(spacing: 15) {
                                Image(systemName: "sparkles.rectangle.stack")
                                    .font(.system(size: 50, weight: .light))
                                    .foregroundColor(luxeEcru)
                                
                                VStack(spacing: 5) {
                                    Text("TAP TO GENERATE AVATAR")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(luxeFlax)
                                        .tracking(1)
                                    Text("Create a digital twin")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 350)
                            .background(Color.black.opacity(0.2))
                        }
                    }
                }
                .frame(width: 340)
                .frame(minHeight: 350, maxHeight: 500)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                // SUBTLE GRADIENT BORDER
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(colors: [luxeEcru.opacity(0.5), .clear, luxeEcru.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 10)
                
                // MARK: - FLOATING CONTROLS
                VStack(spacing: 12) {
                    // History Button
                    if !isGuest {
                        Button(action: { onShowHistory?() }) {
                            CircleButton(
                                icon: "photo.stack",
                                iconColor: luxeEcru,
                                bgColor: Color.black.opacity(0.6)
                            )
                        }
                    }
                    
                    // Save Look
                    if tryOnImage != nil && !isGuest {
                        Button(action: { if !isSaved { onSave?() } }) {
                            CircleButton(
                                icon: isSaved ? "checkmark" : "arrow.down.to.line",
                                iconColor: isSaved ? .black : luxeEcru,
                                bgColor: isSaved ? luxeFlax : Color.black.opacity(0.6),
                                isLoading: isSaving
                            )
                        }
                        .disabled(isSaving || isSaved)
                    }
                    
                    // Close / Reset
                    if tryOnImage != nil || tryOnMessage != nil {
                        Button(action: {
                            withAnimation {
                                tryOnImage = nil
                                tryOnMessage = nil
                                viewModel.isSaved = false
                            }
                        }) {
                            CircleButton(icon: "xmark", iconColor: .white, bgColor: Color.black.opacity(0.6))
                        }
                    }
                    
                    // Regenerate Avatar (Only when avatar exists & not Guest)
                    if !isGuest && tryOnImage == nil && viewModel.userAvatarURL != nil {
                        Button(action: {
                            generateAvatar()
                        }) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.black)
                                .frame(width: 40, height: 40)
                                .background(
                                    LinearGradient(colors: [luxeEcru, luxeFlax], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .clipShape(Circle())
                                .shadow(color: luxeEcru.opacity(0.3), radius: 5)
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
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
        .fullScreenCover(isPresented: $showZoomedImage) {
            HeaderZoomView(image: tryOnImage, imageURL: viewModel.userAvatarURL, onDismiss: { showZoomedImage = false })
        }
    }
    
    // Extracted function to reuse logic safely
    private func generateAvatar() {
        let generator = bodyVM
        let mainVM = viewModel
        
        Task {
            await generator.generateAndSaveAvatar()
            if let newURL = generator.userAvatarURL {
                await MainActor.run { mainVM.userAvatarURL = newURL }
            }
        }
    }
}

// MARK: - Helper Views

struct CircleButton: View {
    let icon: String
    let iconColor: Color
    let bgColor: Color
    var isLoading: Bool = false
    
    var body: some View {
        Circle()
            .fill(bgColor)
            .frame(width: 40, height: 40)
            .background(.ultraThinMaterial) // Glass backing
            .clipShape(Circle())
            .overlay(
                Group {
                    if isLoading {
                        ProgressView().tint(iconColor)
                    } else {
                        Image(systemName: icon)
                            .foregroundColor(iconColor)
                            .font(.system(size: 16, weight: .bold))
                    }
                }
            )
            .overlay(
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

struct HeaderZoomView: View {
    let image: UIImage?
    let imageURL: String?
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea().onTapGesture(perform: onDismiss)
            
            if let img = image {
                Image(uiImage: img).resizable().scaledToFit()
            } else if let urlStr = imageURL, let url = URL(string: urlStr) {
                KFImage(url).resizable().scaledToFit()
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
}
