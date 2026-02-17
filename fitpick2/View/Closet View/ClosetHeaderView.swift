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
                        
                    // ✅ 3. PRIORITY: GENERATING TRY-ON (FIXED)
                    // Added this block so you see a spinner while the AI styles the outfit
                    } else if viewModel.isGeneratingTryOn {
                        VStack(spacing: 15) {
                            ProgressView().tint(Color.luxeEcru)
                            VStack(spacing: 5) {
                                Text("STYLING OUTFIT")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.luxeFlax)
                                    .tracking(2)
                                Text("Applying garments...")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .frame(height: 350)

                    // 4. TRY-ON RESULT
                    } else if let tryOn = tryOnImage {
                        Image(uiImage: tryOn)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 350)
                            .clipped()
                            .layoutPriority(1)
                            .onTapGesture { showZoomedImage = true }
                        
                    // 5. ERROR MESSAGE
                    } else if let message = tryOnMessage {
                        VStack {
                            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundColor(.luxeEcru)
                            Text(message).font(.caption).foregroundColor(.white).multilineTextAlignment(.center)
                        }
                        .frame(height: 350)
                        
                    // 6. EXISTING AVATAR (Default Fallback)
                    } else {
                        let avatarToDisplay: String? = isGuest ? firestoreManager.currentUserData?.userAvatarURL : viewModel.userAvatarURL
                        
                        if let urlStr = avatarToDisplay, let url = URL(string: urlStr) {
                            KFImage(url)
                                .placeholder { ProgressView().tint(Color.luxeEcru).frame(height: 350) }
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 350)
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
                }
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
                    if !isGuest {
                        Button(action: { onShowHistory?() }) {
                            CircleButton(
                                icon: "photo.stack",
                                iconColor: .luxeEcru,
                                bgColor: Color.black.opacity(0.6)
                            )
                        }
                    }
                    
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

// MARK: - Helper Views & Zoom (Retained)
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

struct HeaderZoomView: View {
    let image: UIImage?
    let imageURL: String?
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea().onTapGesture(perform: onDismiss).zIndex(0)
            
            GeometryReader { proxy in
                if let img = image {
                    ZoomableScrollView {
                        Image(uiImage: img).resizable().scaledToFit().frame(width: proxy.size.width, height: proxy.size.height)
                    }
                } else if let urlStr = imageURL, let url = URL(string: urlStr) {
                    ZoomableScrollView {
                        KFImage(url).resizable().scaledToFit().frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
            }.zIndex(1)
            
            VStack { HStack { Spacer(); Button(action: onDismiss) { Image(systemName: "xmark.circle.fill").font(.system(size: 30)).foregroundColor(.white.opacity(0.8)).padding(.top, 50).padding(.trailing, 20).shadow(radius: 5) } }; Spacer() }.zIndex(2)
        }
    }
}

struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    private var content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
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
    func updateUIView(_ uiView: UIScrollView, context: Context) { context.coordinator.hostingController.rootView = content; uiView.setNeedsLayout() }
    func makeCoordinator() -> Coordinator { Coordinator(hostingController: UIHostingController(rootView: content)) }
    class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>
        init(hostingController: UIHostingController<Content>) { self.hostingController = hostingController }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { return hostingController.view }
    }
}
