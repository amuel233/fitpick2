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
    @StateObject private var bodyVM = BodyMeasurementViewModel()
    
    @Binding var tryOnImage: UIImage?
    @Binding var tryOnMessage: String?
    
    @ObservedObject var firestoreManager = FirestoreManager.shared
    
    var onSave: (() -> Void)?
    var onShowHistory: (() -> Void)?
    
    var isSaving: Bool = false
    var isSaved: Bool = false
    var isGuest: Bool = false
    
    @State private var showZoomedImage = false
    
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
                            ProgressView().tint(Color.luxeEcru)
                            Text("Restoring...").font(.caption).foregroundColor(.luxeEcru)
                        }
                        .frame(height: 350)
                        
                    // 2. PRIORITY: GENERATING AVATAR
                    } else if bodyVM.isGenerating {
                         VStack(spacing: 15) {
                             ProgressView().tint(Color.luxeEcru)
                             VStack(spacing: 5) {
                                 Text("CREATING YOUR TWIN")
                                     .font(.headline)
                                     .fontWeight(.bold)
                                     .foregroundColor(.luxeFlax)
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
                            .scaledToFill()
                            .frame(width: 340)
                            .clipped()
                            .layoutPriority(1)
                            .onTapGesture { showZoomedImage = true }
                        
                    // 4. ERROR MESSAGE
                    } else if let message = tryOnMessage {
                        VStack {
                            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundColor(.luxeEcru)
                            Text(message).font(.caption).foregroundColor(.white).multilineTextAlignment(.center)
                        }
                        .frame(height: 350)
                        
                    // 5. EXISTING AVATAR
                    }
                    // Determine which avatar to show.
                    // If isGuest is true, use the App Owner's twin from firestoreManager.
                    // If not, use the viewModel's twin (your own).
                    let avatarToDisplay: String? = isGuest ? firestoreManager.currentUserData?.userAvatarURL : viewModel.userAvatarURL
                    
                    if let urlStr = avatarToDisplay, let url = URL(string: urlStr) {
                        KFImage(url)
                            .placeholder { ProgressView().tint(Color.luxeEcru).frame(height: 350) }
                            .resizable()
                            .scaledToFill()
                            .frame(width: 340)
                            .clipped()
                            .onTapGesture { showZoomedImage = true }
                            .id(urlStr)
                    } else {
                        // Empty State / Generate Button
                        Button(action: { generateAvatar() }) {
                            VStack(spacing: 15) {
                                Image(systemName: "sparkles.rectangle.stack").font(.system(size: 50, weight: .light)).foregroundColor(.luxeEcru)
                                Text("TAP TO GENERATE AVATAR").font(.headline).foregroundColor(.luxeFlax)
                            }
                            .frame(maxWidth: .infinity).frame(height: 350)
                        }
                    }
                }
                .frame(width: 340)
                .frame(minHeight: 350, maxHeight: 500)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(colors: [Color.luxeEcru.opacity(0.5), .clear, Color.luxeEcru.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
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
                                icon: "photo.stack", // ✅ UPDATED ICON
                                iconColor: .luxeEcru,
                                bgColor: Color.black.opacity(0.6)
                            )
                        }
                    }
                    
                    // Save Look
                    if tryOnImage != nil && !isGuest {
                        Button(action: { if !isSaved { onSave?() } }) {
                            CircleButton(
                                icon: isSaved ? "checkmark" : "arrow.down.to.line",
                                iconColor: isSaved ? .black : .luxeEcru,
                                bgColor: isSaved ? .luxeFlax : Color.black.opacity(0.6),
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
                    
                    // Regenerate Avatar
                    if !isGuest && tryOnImage == nil && viewModel.userAvatarURL != nil {
                        Button(action: {
                            generateAvatar()
                        }) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.black)
                                .frame(width: 40, height: 40)
                                .background(Color.luxeGoldGradient)
                                .clipShape(Circle())
                                .shadow(color: Color.luxeEcru.opacity(0.3), radius: 5)
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
            // Update ZoomView to also respect the owner's avatar if guest
            let zoomURL = isGuest ? firestoreManager.currentUserData?.userAvatarURL : viewModel.userAvatarURL
            HeaderZoomView(image: tryOnImage, imageURL: zoomURL, onDismiss: { showZoomedImage = false })
        }
    }
    
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
    
    // ... (Retained existing styling)
    var body: some View {
        Circle() // ... (Retained)
            .fill(bgColor)
            .frame(width: 40, height: 40)
            .background(.ultraThinMaterial)
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

// MARK: - Zoom View with Pinch Gesture
struct HeaderZoomView: View {
    let image: UIImage?
    let imageURL: String?
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Background tap to dismiss
            Color.black.ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
                .zIndex(0)
            
            // Zoomable Image Container
            GeometryReader { proxy in
                if let img = image {
                    ZoomableScrollView {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                } else if let urlStr = imageURL, let url = URL(string: urlStr) {
                    ZoomableScrollView {
                        KFImage(url)
                            .resizable()
                            .scaledToFit()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
            }
            .zIndex(1)
            
            // Close Button Overlay
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill") // Made slightly bolder for visibility
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top, 50)
                            .padding(.trailing, 20)
                            .shadow(radius: 5)
                    }
                }
                Spacer()
            }
            .zIndex(2)
        }
    }
}

// MARK: - UIScrollView Wrapper for Pinch Zoom
struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    private var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        // 1. Configure ScrollView for Zooming
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 5.0 // Allow 5x zoom
        scrollView.minimumZoomScale = 1.0 // Reset to 1x
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear

        // 2. Embed SwiftUI View inside a UIHostingController
        let hostedView = context.coordinator.hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = true
        hostedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostedView.backgroundColor = .clear
        scrollView.addSubview(hostedView)

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // Update content if needed
        context.coordinator.hostingController.rootView = content
        uiView.setNeedsLayout()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(hostingController: UIHostingController(rootView: content))
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>

        init(hostingController: UIHostingController<Content>) {
            self.hostingController = hostingController
        }

        // Return the view to zoom
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController.view
        }
    }
}
