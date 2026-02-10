//
//  UploadPostView.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 1/27/26.
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
    
    // Adjustment States
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // Preview States
    @State private var showPreview = false
    @State private var finalRenderedImage: UIImage? = nil
    
    // Wardrobe Tagging States [New]
    @State private var selectedWardrobeItems: Set<String> = []
    @State private var showWardrobePicker = false
    
    @EnvironmentObject var session: UserSession
    @Environment(\.dismiss) var dismiss
    
    // Updated Theme Colors
    let fitPickGold = Color("fitPickGold")
    let fitPickWhite = Color(red: 245/255, green: 245/255, blue: 247/255)
    let fitPickText = Color(red: 26/255, green: 26/255, blue: 27/255)

    // MARK: - Rendered View
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
        .frame(width: 400, height: 400)
        .background(Color.white)
        .clipped()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                fitPickWhite.ignoresSafeArea()
                .onTapGesture {
                    hideKeyboard()
                }
                
                VStack(spacing: 0) {
                    // Image Section
                    Group {
                        if let _ = postImage {
                            adjustedImageView
                                .overlay(RoundedRectangle(cornerRadius: 15).stroke(fitPickGold, lineWidth: 1))
                                .cornerRadius(15)
                                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { _ in lastOffset = offset }
                                )
                                .gesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            scale = lastScale * value
                                        }
                                        .onEnded { _ in lastScale = scale }
                                )
                                .overlay(controlsOverlay)
                        } else {
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                emptyStatePlaceholder
                            }
                        }
                    }
                    .frame(width: 400, height: 400)
                    .padding(.top, 10)
                    .onChange(of: selectedItem) { _, newValue in
                        handleImageSelection(newValue)
                    }

                    // Wardrobe Tagging Button [New]
                    if postImage != nil {
                        Button(action: { showWardrobePicker = true }) {
                            HStack {
                                Image(systemName: "tag.fill")
                                Text(selectedWardrobeItems.isEmpty ? "Tag items from your closet" : "\(selectedWardrobeItems.count) Items Tagged")
                                    .fontWeight(.medium)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(fitPickGold.opacity(0.1))
                            .foregroundColor(fitPickGold)
                            .cornerRadius(20)
                        }
                        .padding(.top, 15)
                    }

                    // Caption Field
                    TextField(
                        "",
                        text: $caption,
                        prompt: Text("Say something about your fit...").foregroundColor(.gray),
                        axis: .vertical
                    )
                    .lineLimit(3, reservesSpace: true)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .foregroundColor(fitPickText)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .padding(.top, 15)

                    // Preview & Share Button
                    if isUploading {
                        ProgressView().tint(fitPickGold)
                            .padding(.top, 20)
                    } else {
                        Button(action: generatePreview) {
                            Text("Preview & Share")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(postImage == nil || caption.isEmpty ? Color.gray.opacity(0.3) : fitPickGold)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        .disabled(postImage == nil || caption.isEmpty)
                    }
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("New Post")
                        .fontWeight(.bold)
                        .foregroundColor(fitPickText)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(fitPickGold)
                }
            }
            .sheet(isPresented: $showPreview) {
                previewSheetContent
            }
            // Closet Picker Sheet [New]
            .sheet(isPresented: $showWardrobePicker) {
                WardrobeSelectorView(selectedItems: $selectedWardrobeItems)
            }
        }
    }
}

// MARK: - Extensions
extension UploadPostView {
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private var controlsOverlay: some View {
        VStack {
            HStack {
                Button(action: {
                    postImage = nil
                    selectedItem = nil
                    selectedWardrobeItems.removeAll() // Clear tags if image is removed
                }) {
                    Image(systemName: "xmark.circle.fill").background(Circle().fill(Color.white))
                }
                Spacer()
                Button(action: resetPosition) {
                    Image(systemName: "arrow.counterclockwise.circle.fill").background(Circle().fill(Color.white))
                }
            }
            .padding(12).foregroundColor(fitPickGold).font(.title2)
            Spacer()
        }
    }
    
    private var emptyStatePlaceholder: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(Color.white)
            .frame(height: 400)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(fitPickGold.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
            )
            .overlay(VStack(spacing: 12) {
                Image(systemName: "plus.viewfinder").font(.system(size: 40))
                Text("Upload your photo").font(.headline)
            }.foregroundColor(fitPickGold))
    }
    
    private var previewSheetContent: some View {
        ZStack {
            fitPickWhite.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Post Preview")
                    .font(.headline)
                    .foregroundColor(fitPickText)
                    .padding(.top)
                
                if let rendered = finalRenderedImage {
                    Image(uiImage: rendered)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300, height: 300)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(fitPickGold, lineWidth: 1))
                }
                
                ScrollView {
                    VStack(alignment: .center, spacing: 8) {
                        Text(caption)
                            .font(.subheadline)
                            .foregroundColor(fitPickText.opacity(0.8))
                        
                        if !selectedWardrobeItems.isEmpty {
                            Text("\(selectedWardrobeItems.count) items tagged from closet")
                                .font(.caption)
                                .foregroundColor(fitPickGold)
                                .italic()
                        }
                    }
                }
                .frame(maxHeight: 100)
                
                Button(action: uploadPost) {
                    Text("Confirm & Post")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(fitPickGold)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Button("Go Back") { showPreview = false }.foregroundColor(fitPickGold)
                Spacer()
            }
            .padding()
        }
        .presentationDetents([.medium])
    }

    func resetPosition() {
        scale = 1.0; lastScale = 1.0; offset = .zero; lastOffset = .zero
    }
    
    func handleImageSelection(_ item: PhotosPickerItem?) {
        Task {
            if let data = try? await item?.loadTransferable(type: Data.self) {
                postImage = UIImage(data: data)
                resetPosition()
            }
        }
    }

    func generatePreview() {
        let renderer = ImageRenderer(content: adjustedImageView)
        renderer.scale = 3.0
        if let image = renderer.uiImage {
            self.finalRenderedImage = image
            self.showPreview = true
        }
    }

    func uploadPost() {
        guard let finalImg = finalRenderedImage, let email = session.email else { return }
        showPreview = false
        isUploading = true
        
        guard let compressedData = finalImg.jpegData(compressionQuality: 0.7),
              let readyImage = UIImage(data: compressedData) else { return }

        let storageManager = StorageManager()
        storageManager.uploadSocial(email: email, ootd: readyImage) { url in
            let db = Firestore.firestore()
            let uniqueID = "\(email)_\(Int(Date().timeIntervalSince1970))"
            let data: [String: Any] = [
                "id": uniqueID,
                "userEmail": email,
                "username": session.username,
                "caption": caption,
                "imageUrl": url,
                "taggedClothesIds": Array(selectedWardrobeItems), // Save URLs of closet items
                "likes": 0,
                "likedBy": [],
                "likedByNames": [],
                "timestamp": FieldValue.serverTimestamp()
            ]
            db.collection("socials").document(uniqueID).setData(data) { _ in
                isUploading = false
                dismiss()
            }
        }
    }
}
