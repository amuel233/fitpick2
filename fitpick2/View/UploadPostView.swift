//
//  UploadPostView.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 1/27/26.
//

import SwiftUI
import PhotosUI
import FirebaseFirestore

struct UploadPostView: View {
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var postImage: UIImage? = nil
    @State private var caption: String = ""
    @State private var isUploading = false
    
    @EnvironmentObject var session: UserSession
    @Environment(\.dismiss) var dismiss
    
    let fitPickGold = Color("fitPickGold")
    let fitPickBlack = Color(red: 26/255, green: 26/255, blue: 27/255)

    var body: some View {
        NavigationStack {
            ZStack {
                fitPickBlack.ignoresSafeArea()
                
                VStack(spacing: 25) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        if let image = postImage {
                            Image(uiImage: image).resizable().scaledToFill()
                                .frame(height: 500).frame(maxWidth: .infinity)
                                .cornerRadius(15).clipped()
                                .overlay(RoundedRectangle(cornerRadius: 15).stroke(fitPickGold, lineWidth: 1))
                        } else {
                            RoundedRectangle(cornerRadius: 15).fill(Color.white.opacity(0.1))
                                .frame(height: 500)
                                .overlay(VStack {
                                    Image(systemName: "photo.on.rectangle.angled").font(.largeTitle)
                                    Text("Upload your photo").font(.callout)
                                }.foregroundColor(fitPickGold))
                        }
                    }
                    .onChange(of: selectedItem) { _, newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                postImage = UIImage(data: data)
                            }
                        }
                    }

                    TextField("Say something about your fit...", text: $caption)
                        .padding().background(Color.white.opacity(0.1)).cornerRadius(10)
                        .foregroundColor(.white).padding(.horizontal)

                    if isUploading {
                        ProgressView().tint(fitPickGold)
                    } else {
                        Button(action: uploadPost) {
                            Text("Share OOTD").font(.headline).foregroundColor(.black)
                                .frame(maxWidth: .infinity).padding().background(fitPickGold).cornerRadius(10)
                        }
                        .padding(.horizontal).disabled(postImage == nil || caption.isEmpty)
                    }
                    Spacer()
                }
                .padding(.top)
            }
            .navigationTitle("New Post")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(fitPickGold)
                }
            }
        }
    }

    func uploadPost() {
        guard let image = postImage, let email = session.email else { return }
        isUploading = true
        let storageManager = StorageManager()
        
        storageManager.uploadSocial(email: email, ootd: image) { url in
            let db = Firestore.firestore()
            let uniqueID = "\(email)_\(Int(Date().timeIntervalSince1970))"
            
            let data: [String: Any] = [
                "id": uniqueID,
                "userEmail": email,
                "username": session.username,
                "caption": caption,
                "imageUrl": url,
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
