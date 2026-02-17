//
//  UploadPostView.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 2/9/26.
//

import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseAuth

struct UploadPostView: View {
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var postImage: UIImage? = nil
    @State private var caption: String = ""
    @State private var isUploading = false
    
    // Image Adjustment States
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // Preview & Picker States
    @State private var showPreview = false
    @State private var finalRenderedImage: UIImage? = nil
    @State private var selectedWardrobeItems: Set<String> = []
    @State private var showWardrobePicker = false
    
    // MARK: - Keyboard & LuxeAlert States
    @FocusState private var isCaptionFocused: Bool
    @State private var showExitAlert = false
    
    @EnvironmentObject var session: UserSession
    @Environment(\.dismiss) var dismiss
    
    var adjustedImageView: some View {
        ZStack {
            if let image = postImage {
                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .frame(width: 380, height: 480)
        .background(Color.luxeBlack)
        .clipped()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.luxeDeepOnyx.ignoresSafeArea()
                    .onTapGesture { isCaptionFocused = false }
                
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 30) {
                            
                            // MARK: - THE CANVAS
                            VStack(spacing: 12) {
                                if let _ = postImage {
                                    adjustedImageView
                                        .cornerRadius(2)
                                        .overlay(Rectangle().stroke(Color.luxeEcru.opacity(0.3), lineWidth: 0.5))
                                        .gesture(DragGesture().onChanged { value in
                                            offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
                                        }.onEnded { _ in lastOffset = offset })
                                        .gesture(MagnificationGesture().onChanged { value in
                                            scale = lastScale * value
                                        }.onEnded { _ in lastScale = scale })
                                        .overlay(controlsOverlay)
                                } else {
                                    PhotosPicker(selection: $selectedItem, matching: .images) {
                                        emptyStatePlaceholder
                                    }
                                }
                            }
                            .padding(.top, 20)
                            .onChange(of: selectedItem) { _, newValue in
                                handleImageSelection(newValue)
                            }

                            if postImage != nil {
                                // EDITORIAL CONTROLS
                                VStack(spacing: 35) {
                                    Button(action: { showWardrobePicker = true }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "tag").font(.system(size: 14))
                                            Text(selectedWardrobeItems.isEmpty ? "CURATE CLOSET TAGS" : "\(selectedWardrobeItems.count) ITEMS LINKED")
                                                .font(.system(size: 11, weight: .black)).tracking(2)
                                        }
                                        .foregroundColor(.luxeBeige)
                                        .padding(.vertical, 12).padding(.horizontal, 24)
                                        .background(Capsule().strokeBorder(Color.luxeGoldGradient, lineWidth: 1))
                                    }

                                    // CAPTION
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("THE STATEMENT")
                                            .font(.system(size: 10, weight: .black)).tracking(3)
                                            .foregroundColor(Color.luxeEcru)
                                        
                                        TextField("", text: $caption, prompt: Text("Write your fashion story...").foregroundColor(.gray), axis: .vertical)
                                            .focused($isCaptionFocused)
                                            .font(.system(size: 15, weight: .regular, design: .serif)).italic()
                                            .padding()
                                            .background(Color.luxeRichCharcoal.opacity(0.3))
                                            .cornerRadius(4)
                                            .foregroundColor(.luxeBeige)
                                            .overlay(Rectangle().stroke(Color.luxeEcru.opacity(0.1), lineWidth: 1))
                                    }
                                    .padding(.horizontal, 30)
                                    .id("captionField")

                                    if isUploading {
                                        ProgressView().tint(Color.luxeFlax)
                                    } else {
                                        Button(action: generatePreview) {
                                            Text("REVEAL LOOK")
                                                .font(.system(size: 14, weight: .black)).tracking(4)
                                                .foregroundColor(.black)
                                                .frame(maxWidth: .infinity).padding(.vertical, 18)
                                                .background(Color.luxeGoldGradient)
                                                .cornerRadius(2)
                                        }
                                        .padding(.horizontal, 30)
                                        .opacity(postImage == nil || caption.isEmpty ? 0.3 : 1.0)
                                        .disabled(postImage == nil || caption.isEmpty)
                                        .id("revealButton")
                                    }
                                }
                            }
                            
                            // FIXED BUFFER: This prevents the "Invalid Frame" error by
                            // providing a stable, pre-calculated space at the bottom.
                            Color.clear.frame(height: 350)
                        }
                    }
                    .onChange(of: isCaptionFocused) { _, focused in
                        if focused {
                            // Wait for keyboard to settle, then scroll to the button
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                    proxy.scrollTo("revealButton", anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("DONE") { isCaptionFocused = false }
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.luxeFlax)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("NEW LOOK").font(.system(size: 14, weight: .black)).tracking(3).foregroundColor(Color.luxeEcru)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("CLOSE") {
                        if postImage != nil || !caption.isEmpty {
                            withAnimation { showExitAlert = true }
                        } else {
                            dismiss()
                        }
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.luxeBeige.opacity(0.6))
                }
            }
            // Quirky Fashion LuxeAlert
            .luxeAlert(
                isPresented: $showExitAlert,
                title: "VIBE CHECK FAILED?",
                message: "Wait, darling—this look is a moment. Discarding now means this aesthetic never sees the light of day.",
                confirmTitle: "DISCARD",
                onConfirm: { dismiss() }
            )
            .sheet(isPresented: $showPreview) { previewSheetContent }
            .sheet(isPresented: $showWardrobePicker) {
                WardrobeSelectorView(selectedItems: $selectedWardrobeItems)
            }
        }
    }
}

// Logic components and extensions remain exactly as in previous versions
extension UploadPostView {
    private var controlsOverlay: some View {
        VStack {
            HStack {
                Button(action: { postImage = nil; selectedItem = nil }) {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                        .padding(10).background(BlurView(style: .systemUltraThinMaterialDark)).clipShape(Circle())
                }
                Spacer()
                Button(action: resetPosition) {
                    Image(systemName: "arrow.counterclockwise").font(.system(size: 12, weight: .bold))
                        .padding(10).background(BlurView(style: .systemUltraThinMaterialDark)).clipShape(Circle())
                }
            }
            .padding(15).foregroundColor(.luxeBeige)
            Spacer()
        }
    }

    private var emptyStatePlaceholder: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().stroke(Color.luxeEcru.opacity(0.2), lineWidth: 1).frame(width: 80, height: 80)
                Image(systemName: "plus").font(.system(size: 24, weight: .light)).foregroundColor(.luxeEcru)
            }
            Text("SELECT FROM GALLERY").font(.system(size: 11, weight: .black)).tracking(4).foregroundColor(.luxeEcru)
        }
        .frame(width: 380, height: 480)
        .background(Color.luxeRichCharcoal.opacity(0.2))
        .overlay(Rectangle().stroke(Color.luxeEcru.opacity(0.2), style: StrokeStyle(lineWidth: 0.5, dash: [5])))
    }

    private var previewSheetContent: some View {
        ZStack {
            Color.luxeBlack.ignoresSafeArea()
            VStack(spacing: 30) {
                Text("VIBE CHECK").font(.system(size: 14, weight: .black)).tracking(5).foregroundColor(Color.luxeEcru)
                if let rendered = finalRenderedImage {
                    Image(uiImage: rendered).resizable().scaledToFit().frame(width: 300).overlay(Rectangle().stroke(Color.luxeEcru, lineWidth: 0.5))
                }
                Text(caption).font(.system(size: 16, design: .serif)).italic().foregroundColor(.luxeBeige).multilineTextAlignment(.center)
                Button(action: uploadPost) {
                    Text("PUBLISH LOOK").font(.system(size: 14, weight: .black)).tracking(3).foregroundColor(.black).frame(maxWidth: .infinity).padding().background(Color.luxeGoldGradient)
                }.padding(.horizontal, 40)
                Button("RE-EDIT") { showPreview = false }.font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
            }.padding()
        }
    }

    func resetPosition() { scale = 1.0; lastScale = 1.0; offset = .zero; lastOffset = .zero }
    func handleImageSelection(_ item: PhotosPickerItem?) {
        Task { if let data = try? await item?.loadTransferable(type: Data.self) { postImage = UIImage(data: data); resetPosition() } }
    }
    func generatePreview() {
        let renderer = ImageRenderer(content: adjustedImageView); renderer.scale = 3.0
        if let image = renderer.uiImage { self.finalRenderedImage = image; self.showPreview = true }
    }
    func uploadPost() {
        guard let finalImg = finalRenderedImage, let email = session.email else { return }
        showPreview = false; isUploading = true
        StorageManager().uploadSocial(email: email, ootd: finalImg) { url in
            let uniqueID = "\(email)_\(Int(Date().timeIntervalSince1970))"
            let data: [String: Any] = ["id": uniqueID, "userEmail": email, "username": session.username, "caption": caption, "imageUrl": url, "taggedClothesIds": Array(selectedWardrobeItems), "likes": 0, "likedBy": [], "likedByNames": [], "timestamp": FieldValue.serverTimestamp()]
            Firestore.firestore().collection("socials").document(uniqueID).setData(data) { _ in isUploading = false; dismiss() }
        }
    }
}

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView { UIVisualEffectView(effect: UIBlurEffect(style: style)) }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
