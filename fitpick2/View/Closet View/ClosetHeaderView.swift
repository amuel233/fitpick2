//
//  ClosetHeaderView.swift
//  fitpick
//
//  Created by Bry on 2/13/26.
//

import SwiftUI
import Kingfisher
// ✅ Removed FirebaseAuth and FirebaseFirestore imports - logic successfully moved to ViewModel

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
    
    private var cardDisplayHeight: CGFloat {
        max(390, min(UIScreen.main.bounds.height * 0.44, 490))
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                
                // MARK: - MAIN DISPLAY AREA (FROSTED GLASS CARD - MAXIMIZED AREA)
                ZStack {
                    // 1. PRIORITY: RESTORING LOOK (From History)
                    if viewModel.isRestoringLook {
                        VStack(spacing: 10) {
                            ProgressView().tint(Color.luxeEcru)
                            Text("Restoring...").font(.caption).foregroundColor(.luxeEcru)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
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
                         .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                    // 3. PRIORITY: GENERATING TRY-ON (DYNAMIC LOADING)
                    } else if viewModel.isGeneratingTryOn {
                        TryOnLoadingView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // 4. TRY-ON RESULT (MAXIMIZED DISPLAY)
                    } else if let tryOn = tryOnImage {
                        Image(uiImage: tryOn)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .layoutPriority(1)
                            .contentShape(Rectangle())
                            .onTapGesture { showZoomedImage = true }
                        
                    // 5. ERROR MESSAGE
                    } else if let message = tryOnMessage {
                        VStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundColor(.luxeEcru)
                            Text(message).font(.caption).foregroundColor(.white).multilineTextAlignment(.center).padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                    // 6. EXISTING AVATAR (Default Fallback - MAXIMIZED)
                    } else {
                        let avatarToDisplay: String? = isGuest ? firestoreManager.currentUserData?.userAvatarURL : viewModel.userAvatarURL
                        
                        if let urlStr = avatarToDisplay, let url = URL(string: urlStr) {
                            KFImage(url)
                                .placeholder { ProgressView().tint(Color.luxeEcru).frame(maxWidth: .infinity, maxHeight: .infinity) }
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                                .onTapGesture { showZoomedImage = true }
                                .id(urlStr)
                        } else {
                            // Empty State / Generate Button
                            Button(action: { Task { await viewModel.generateAvatar(using: bodyVM) } }) {
                                VStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.luxeFlax.opacity(0.12))
                                            .frame(width: 80, height: 80)
                                        Image(systemName: "sparkles.rectangle.stack")
                                            .font(.system(size: 38, weight: .light))
                                            .foregroundStyle(Color.luxeGoldGradient)
                                    }
                                    
                                    VStack(spacing: 6) {
                                        Text("TAP TO GENERATE AVATAR")
                                            .font(.system(size: 14, weight: .bold, design: .serif))
                                            .foregroundColor(.luxeFlax)
                                            .tracking(2)
                                        Text("Create your AI digital twin to try on outfits")
                                            .font(.caption)
                                            .foregroundColor(.luxeBeige.opacity(0.6))
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                }
                // CARD STYLING (LIQUID GLASS & EXPANDED CANVAS)
                .frame(maxWidth: .infinity)
                .frame(height: cardDisplayHeight)
                .liquidGlassCard(cornerRadius: 24)
                .padding(.horizontal, 14)
                
                // MARK: - FLOATING CONTROLS
                VStack(spacing: 12) {
                    if !isGuest {
                        Button(action: { onShowHistory?() }) {
                            CircleButton(
                                icon: "photo.stack",
                                iconColor: .luxeEcru,
                                bgColor: Color.black.opacity(0.4)
                            )
                        }
                    }
                    
                    if tryOnImage != nil && !isGuest {
                        Button(action: { if !isSaved { onSave?() } }) {
                            CircleButton(
                                icon: isSaved ? "checkmark" : "arrow.down.to.line",
                                iconColor: isSaved ? .black : .luxeEcru,
                                bgColor: isSaved ? .luxeFlax : Color.black.opacity(0.4),
                                isLoading: isSaving
                            )
                        }
                        .disabled(isSaving || isSaved)
                    }
                    
                    if tryOnImage != nil || tryOnMessage != nil {
                        Button(action: {
                            withAnimation {
                                tryOnImage = nil
                                tryOnMessage = nil
                                viewModel.isSaved = false
                            }
                        }) {
                            CircleButton(icon: "xmark", iconColor: .white, bgColor: Color.black.opacity(0.4))
                        }
                    }
                    
                    if !isGuest && tryOnImage == nil && viewModel.userAvatarURL != nil {
                        Button(action: {
                            Task { await viewModel.generateAvatar(using: bodyVM) }
                        }) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.black)
                                .font(.system(size: 15, weight: .bold))
                                .frame(width: 42, height: 42)
                                .liquidGlassGoldButton(cornerRadius: 21)
                        }
                        .disabled(bodyVM.isGenerating)
                    }
                }
                .padding(12)
                .padding(.trailing, 16)
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .fullScreenCover(isPresented: $showZoomedImage) {
            let zoomURL = isGuest ? firestoreManager.currentUserData?.userAvatarURL : viewModel.userAvatarURL
            HeaderZoomView(image: tryOnImage, imageURL: zoomURL, onDismiss: { showZoomedImage = false })
        }
    }
}

// MARK: - Dynamic Loading View
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
            // Pulsing Icon
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
            
            // Cycling Text
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
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
            Circle()
                .fill(bgColor)
            
            if isLoading {
                ProgressView().tint(iconColor)
            } else {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 15, weight: .bold))
            }
        }
        .frame(width: 42, height: 42)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(
                LinearGradient(
                    colors: [.white.opacity(0.55), Color.luxeEcru.opacity(0.35)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Zoom View
struct HeaderZoomView: View {
    let image: UIImage?
    let imageURL: String?
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Liquid Glass Background
            LiquidGlassBackgroundView()
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
                .zIndex(0)
            
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.85))
                .ignoresSafeArea()
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
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.luxeBeige)
                            .frame(width: 40, height: 40)
                            .liquidGlassPill(cornerRadius: 20)
                            .padding(.top, 50)
                            .padding(.trailing, 20)
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
