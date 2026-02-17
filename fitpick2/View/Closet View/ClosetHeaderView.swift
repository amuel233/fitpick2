//
//  ClosetHeaderView.swift
//  fitpick
//
//  Created by Bry on 2/13/26.
//

import SwiftUI
import Kingfisher

struct ClosetHeaderView: View {
    // MARK: - Properties
    @ObservedObject var viewModel: ClosetViewModel
    @StateObject private var bodyVM = BodyMeasurementViewModel()
    
    // Bindings to Parent View (ClosetView)
    @Binding var tryOnImage: UIImage?
    @Binding var tryOnMessage: String?
    
    @ObservedObject var firestoreManager = FirestoreManager.shared
    
    // Callbacks
    var onSave: (() -> Void)?
    var onShowHistory: (() -> Void)?
    
    // State Flags
    var isSaving: Bool = false
    var isSaved: Bool = false
    var isGuest: Bool = false
    
    // Local UI State
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
                    
                    // 1. PRIORITY: RESTORING LOOK (From History)
                    if viewModel.isRestoringLook {
                        VStack(spacing: 10) {
                            ProgressView().tint(Color.luxeEcru)
                            Text("Restoring...").font(.caption).foregroundColor(.luxeEcru)
                        }
                        .frame(height: 350)
                        
                    // 2. PRIORITY: GENERATING AVATAR (BodyMeasurementViewModel)
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
                        
                    // ✅ 3. PRIORITY: GENERATING TRY-ON (NEW DYNAMIC LOADING)
                    // Displays cycling text and pulsing animation while AI styles the outfit
                    } else if viewModel.isGeneratingTryOn {
                        TryOnLoadingView()
                            .frame(height: 350)

                    // ✅ 4. TRY-ON RESULT (FIXED: No Cropping)
                    } else if let tryOn = tryOnImage {
                        Image(uiImage: tryOn)
                            .resizable()
                            .scaledToFit() // fit ensures head/feet aren't cut off
                            .frame(maxWidth: .infinity)
                            .frame(height: 350)
                            .layoutPriority(1)
                            .onTapGesture { showZoomedImage = true }
                        
                    // 5. ERROR MESSAGE
                    } else if let message = tryOnMessage {
                        VStack {
                            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundColor(.luxeEcru)
                            Text(message).font(.caption).foregroundColor(.white).multilineTextAlignment(.center)
                        }
                        .frame(height: 350)
                        
                    // ✅ 6. EXISTING AVATAR (Default Fallback) (FIXED: No Cropping)
                    } else {
                        let avatarToDisplay: String? = isGuest ? firestoreManager.currentUserData?.userAvatarURL : viewModel.userAvatarURL
                        
                        if let urlStr = avatarToDisplay, let url = URL(string: urlStr) {
                            KFImage(url)
                                .placeholder { ProgressView().tint(Color.luxeEcru).frame(height: 350) }
                                .resizable()
                                .scaledToFit() // fit ensures full avatar visibility
                                .frame(maxWidth: .infinity)
                                .frame(height: 350)
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
                }
                // ✅ CARD STYLING (FIXED: Max Width 380 prevents infinite stretch on Pro Max)
                .frame(maxWidth: 380)
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
                .padding(.horizontal, 20)
                
                // MARK: - FLOATING CONTROLS
                VStack(spacing: 12) {
                    // History Button
                    if !isGuest {
                        Button(action: { onShowHistory?() }) {
                            CircleButton(
                                icon: "photo.stack",
                                iconColor: .luxeEcru,
                                bgColor: Color.black.opacity(0.6)
                            )
                        }
                    }
                    
                    // Save Button (Only shows when result is available)
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
                    
                    // Close / Clear Button
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
                    
                    // Generate Avatar Shortcut (Only if avatar exists but user wants to regen)
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
                .padding(.trailing, 20)
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .fullScreenCover(isPresented: $showZoomedImage) {
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

// MARK: - ✅ NEW: Dynamic Loading View
struct TryOnLoadingView: View {
    @State private var step = 0
    private let steps = [
        "Scanning Body Metrics...",
        "Analyzing Fabric Texture...",
        "Simulating Cloth Physics...",
        "Calculating Lighting...",
        "Rendering Final Look..."
    ]
    
    // Timer to cycle text every 1.5 seconds
    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 20) {
            // 1. Pulsing Icon
            ZStack {
                Circle()
                    .stroke(Color.luxeEcru.opacity(0.3), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.luxeFlax, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(Double(step) * 360)) // Rotate based on step
                    .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: step)
                
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                    .foregroundColor(.luxeEcru)
                    .symbolEffect(.pulse) // iOS 17 Native Pulse
            }
            
            // 2. Cycling Text
            VStack(spacing: 8) {
                Text("STYLING OUTFIT")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.luxeFlax)
                    .tracking(2)
                
                // Animated text change
                Text(steps[step % steps.count])
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .transition(.opacity)
                    .id("step_\(step)")
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                step += 1
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

// MARK: - Zoom View
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
                        Image(systemName: "xmark.circle.fill")
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
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 5.0
        scrollView.minimumZoomScale = 1.0
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear

        let hostedView = context.coordinator.hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = true
        hostedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostedView.backgroundColor = .clear
        scrollView.addSubview(hostedView)

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
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

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController.view
        }
    }
}
