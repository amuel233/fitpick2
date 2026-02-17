//
//  UploadPostView.swift
//  fitpick2
//

import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import Kingfisher

struct UploadPostView: View {
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var postImage: UIImage? = nil
    @State private var caption: String = ""
    @State private var isUploading = false
    
    // Adjustment States (Logic preserved)
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    @State private var showCancelWarning = false
    @State private var selectedWardrobeItems: Set<String> = []
    @State private var showWardrobePicker = false
    
    // Using the fixed Manager logic
    @ObservedObject var firestoreManager = FirestoreManager.shared
    @Environment(\.dismiss) var dismiss
    
    let fitPickGold = Color(red: 0.75, green: 0.60, blue: 0.22)
    let editorBlack = Color(red: 10/255, green: 10/255, blue: 10/255)
    let surfaceDark = Color(white: 0.08)

    var body: some View {
        NavigationStack {
            ZStack {
                editorBlack.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - STUDIO HEADER (Fixed Height)
                    headerView
                        .frame(height: 60)
                        .padding(.horizontal, 20)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 25) {
                            
                            // MARK: - FIXED IMAGE CANVAS
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(surfaceDark)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                    )
                                
                                if let image = postImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: UIScreen.main.bounds.width - 40, height: 480) // Fixed dimensions
                                        .scaleEffect(scale)
                                        .offset(offset)
                                        .gesture(zoomGesture)
                                        .gesture(dragGesture)
                                } else {
                                    PhotosPicker(selection: $selectedItem, matching: .images) {
                                        VStack(spacing: 15) {
                                            Image(systemName: "plus.viewfinder")
                                                .font(.system(size: 32, weight: .thin))
                                            Text("IMPORT PHOTO")
                                                .font(.system(size: 10, weight: .black)).tracking(3)
                                        }
                                        .foregroundColor(fitPickGold.opacity(0.5))
                                    }
                                }
                            }
                            .frame(height: 480) // Constrains the canvas
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(.horizontal, 20)
                            
                            // MARK: - INPUT FIELDS
                            VStack(alignment: .leading, spacing: 30) {
                                // Narrative field
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("NARRATIVE")
                                        .font(.system(size: 10, weight: .black)).tracking(2)
                                        .foregroundColor(fitPickGold)
                                    
                                    TextField("", text: $caption, prompt: Text("Describe the vibe...").foregroundColor(.white.opacity(0.2)))
                                        .font(.system(size: 15, design: .serif)).italic()
                                        .foregroundColor(.white)
                                        .tint(fitPickGold)
                                }
                                .padding(.bottom, 10)
                                .overlay(Rectangle().frame(height: 0.5).foregroundColor(.white.opacity(0.1)), alignment: .bottom)
                                
                                // Wardrobe Button
                                Button(action: { showWardrobePicker = true }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("LINKED WARDROBE")
                                                .font(.system(size: 10, weight: .black)).tracking(2)
                                                .foregroundColor(fitPickGold)
                                            
                                            Text(selectedWardrobeItems.isEmpty ? "No items selected" : "\(selectedWardrobeItems.count) ITEMS TAGGED")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.4))
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(fitPickGold)
                                    }
                                    .padding(20)
                                    .background(surfaceDark)
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            // Bottom spacing for scroll comfort
                            Spacer(minLength: 50)
                        }
                    }
                }
            }
        }
        .luxeAlert(
            isPresented: $showCancelWarning,
            title: "DISCARD EDIT?",
            message: "Your creation and story will be lost. Are you sure?",
            confirmTitle: "DISCARD",
            cancelTitle: "STAY",
            onConfirm: { dismiss() }
        )
        .task(id: selectedItem) {
            if let data = try? await selectedItem?.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                postImage = uiImage
            }
        }
        .sheet(isPresented: $showWardrobePicker) {
            WardrobeSelectorView(selectedItems: $selectedWardrobeItems)
                .presentationDetents([.medium, .large])
                .presentationBackground(editorBlack)
        }
    }

    // MARK: - SUBVIEWS
    private var headerView: some View {
        HStack {
            Button(action: { showCancelWarning = true }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.05)))
            }
            
            Spacer()
            
            Text("POST")
                .font(.system(size: 13, weight: .black))
                .tracking(6)
                .foregroundColor(fitPickGold)
            
            Spacer()
            
            if postImage != nil {
                Button(action: { sharePost() }) {
                    if isUploading {
                        ProgressView().tint(fitPickGold)
                    } else {
                        Text("POST")
                            .font(.system(size: 11, weight: .black))
                            .tracking(2)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(fitPickGold)
                            .foregroundColor(.black)
                            .clipShape(Capsule())
                    }
                }
            } else {
                Color.clear.frame(width: 36, height: 36)
            }
        }
    }

    // MARK: - UNAFFECTED LOGIC
    var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { val in scale = lastScale * val }
            .onEnded { _ in lastScale = scale }
    }
    
    var dragGesture: some Gesture {
        DragGesture()
            .onChanged { val in offset = CGSize(width: lastOffset.width + val.translation.width, height: lastOffset.height + val.translation.height) }
            .onEnded { _ in lastOffset = offset }
    }
    
    func sharePost() {
        guard let postImage = postImage else { return }
        isUploading = true
        let targetSize = CGSize(width: 1080, height: 1350)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let renderedImage = renderer.image { ctx in
            let viewRect = CGRect(origin: .zero, size: targetSize)
            UIColor.black.setFill()
            ctx.fill(viewRect)
            let aspectWidth = targetSize.width / postImage.size.width
            let aspectHeight = targetSize.height / postImage.size.height
            let minAspect = max(aspectWidth, aspectHeight)
            let scaledWidth = postImage.size.width * minAspect * scale
            let scaledHeight = postImage.size.height * minAspect * scale
            let drawRect = CGRect(x: (targetSize.width - scaledWidth) / 2 + (offset.width * (targetSize.width / 350)), y: (targetSize.height - scaledHeight) / 2 + (offset.height * (targetSize.height / 450)), width: scaledWidth, height: scaledHeight)
            postImage.draw(in: drawRect)
        }
        uploadPost(image: renderedImage)
    }

    func uploadPost(image: UIImage) {
        guard let userEmail = firestoreManager.currentEmail else { isUploading = false; return }
        let storageRef = Storage.storage().reference().child("posts/\(UUID().uuidString).jpg")
        guard let imageData = image.jpegData(compressionQuality: 0.75) else { return }
        storageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error { isUploading = false; return }
            storageRef.downloadURL { url, _ in
                guard let url = url else { return }
                let db = Firestore.firestore()
                let postData: [String: Any] = [
                    "userEmail": userEmail,
                    "username": firestoreManager.currentUserData?.username ?? "Anonymous",
                    "imageUrl": url.absoluteString,
                    "caption": caption,
                    "timestamp": FieldValue.serverTimestamp(),
                    "likes": 0,
                    "taggedItems": Array(selectedWardrobeItems)
                ]
                db.collection("posts").addDocument(data: postData) { _ in
                    isUploading = false
                    dismiss()
                }
            }
        }
    }
}
