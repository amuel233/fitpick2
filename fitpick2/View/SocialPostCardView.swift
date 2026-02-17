//
//  SocialPostCardView.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 1/27/26.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAILogic
import UIKit

struct SocialPostCardView: View {
    let post: SocialsPost
    let goldColor: Color
    
    @ObservedObject var firestoreManager: FirestoreManager
    @State private var isExpanded: Bool = false
    @State private var avatarURL: String?
    @EnvironmentObject var session: UserSession
    @State private var backgroundPrompt: String = ""
    
    @State private var generatedImage: UIImage?
    @State private var isShowingPopup = false
    @State private var isProcessing = false
    @State private var showingDeleteAlert = false
    
    @State private var isEditingCaption = false
    @State private var editedCaption: String = ""
    
    // MARK: - Updated Luxe Theme Colors
    let fitPickBlack = Color.luxeSpotlightGradient // Using deep onyx for the card base
    let fitPickDarkGray = Color.luxeRichCharcoal // Using rich charcoal for placeholder/inputs

    var body: some View {
        ZStack {
            // --- MAIN CARD CONTENT ---
            VStack(alignment: .leading, spacing: 15) {
                // --- HEADER ---
                HStack {
                    let myEmail = firestoreManager.currentEmail ?? ""
                    let targetEmail = post.userEmail
                    let isFollowing = firestoreManager.currentUserData?.following.contains(targetEmail) ?? false
                    
                    NavigationLink(destination: ClosetView(targetUserEmail: targetEmail, targetUsername: post.username)) {
                        Text(post.username.uppercased())
                            .font(.system(size: 13, weight: .black))
                            .tracking(2)
                            .foregroundColor(Color.luxeEcru) // Matches the Dark Gold/Bronze
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(!isFollowing)
                    
                    Spacer()
                    
                    if myEmail == targetEmail {
                        HStack(spacing: 15) {
                            Button(action: {
                                editedCaption = post.caption
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isEditingCaption.toggle()
                                }
                            }) {
                                Text(isEditingCaption ? "CANCEL" : "EDIT")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(isEditingCaption ? .gray : Color.luxeFlax)
                            }
                            
                            if !isEditingCaption {
                                Button(action: { withAnimation { showingDeleteAlert = true } }) {
                                    Text("REMOVE")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Color.luxeBeige.opacity(0.6))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .overlay(Rectangle().stroke(Color.luxeEcru.opacity(0.3), lineWidth: 1))
                                }
                            }
                        }
                    } else {
                        Button(action: {
                            firestoreManager.toggleFollow(currentEmail: myEmail, targetEmail: targetEmail, isFollowing: isFollowing)
                        }) {
                            Text(isFollowing ? "FOLLOWING" : "FOLLOW")
                                .font(.system(size: 10, weight: .black))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background {
                                    if isFollowing {
                                        Color.clear
                                    } else {
                                        Color.luxeGoldGradient
                                    }
                                }
                                .foregroundColor(isFollowing ? .gray : .black)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(Color.luxeEcru, lineWidth: isFollowing ? 1 : 0)
                                )
                        }
                    }
                }
                .padding(.horizontal)
                
                // --- IMAGE SECTION ---
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: URL(string: post.imageUrl)) { phase in
                        switch phase {
                        case .empty: Rectangle().fill(fitPickDarkGray).frame(width: UIScreen.main.bounds.width - 32, height: 450)
                        case .success(let image): image.resizable().aspectRatio(contentMode: .fill).frame(width: UIScreen.main.bounds.width - 32, height: 450).clipped()
                        case .failure: Rectangle().fill(Color.luxeEcru.opacity(0.1)).frame(width: UIScreen.main.bounds.width - 32, height: 450)
                        @unknown default: EmptyView()
                        }
                    }
                    
                    Button(action: { Task { isProcessing = true; await tryFit(); isProcessing = false } }) {
                        ZStack {
                            if isProcessing { ProgressView().tint(.white) }
                            else { Image(systemName: "sparkles").font(.system(size: 18, weight: .bold)) }
                        }
                        .frame(width: 44, height: 44).background(.ultraThinMaterial).foregroundColor(.white).clipShape(Circle())
                    }.padding(12).disabled(isProcessing)
                }.padding(.horizontal)

                // --- LIKES & CAPTION ---
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Button(action: {
                            if let email = firestoreManager.currentEmail {
                                let myUsername = firestoreManager.currentUserData?.username ?? "User"
                                firestoreManager.toggleLike(post: post, userEmail: email, username: myUsername)
                            }
                        }) {
                            Image(systemName: post.safeLikedBy.contains(firestoreManager.currentEmail ?? "") ? "heart.fill" : "heart")
                                .font(.system(size: 20)).foregroundColor(Color.luxeFlax)
                        }
                        if post.likes > 0 { instagramStyleLikedView.font(.system(size: 12, weight: .bold)).foregroundColor(Color.luxeBeige) }
                    }
                    
                    if isEditingCaption {
                        VStack(alignment: .trailing, spacing: 10) {
                            TextField("Edit your statement...", text: $editedCaption, axis: .vertical)
                                .font(.system(size: 14, design: .serif)).padding(12).background(fitPickDarkGray).cornerRadius(4).foregroundColor(Color.luxeBeige)
                            Button("SAVE CHANGES") { updateCaption() }.font(.system(size: 10, weight: .black)).foregroundColor(Color.luxeFlax)
                        }
                    } else if !post.caption.isEmpty {
                        Text(post.caption).font(.system(size: 15, weight: .regular, design: .serif)).italic().lineSpacing(4).foregroundColor(Color.luxeBeige.opacity(0.9))
                    }
                    Text(post.timestamp, style: .relative).font(.system(size: 9, weight: .bold)).tracking(1).foregroundColor(.gray).textCase(.uppercase)
                }.padding(.horizontal)
            }
            .padding(.vertical, 15)
            .background(Color.clear)
            .background(fitPickBlack)
            .overlay(
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.luxeEcru.opacity(0.1))
                        .frame(height: 0.5)
                        .padding(.horizontal)
                }
            )
            .blur(radius: showingDeleteAlert ? 4 : 0)
            .luxeAlert(
                isPresented: $showingDeleteAlert,
                title: "REMOVE THIS LOOK?",
                message: "This vibe will be permanently removed from your digital closet. Are you sure it's out of season?",
                confirmTitle: "REMOVE",
                cancelTitle: "KEEP IT",
                onConfirm: {
                    firestoreManager.deletePost(post: post)
                    showingDeleteAlert = false
                }
            )
        }
        .sheet(isPresented: $isShowingPopup) {
            VStack(spacing: 25) {
                VStack(spacing: 8) {
                    Capsule().fill(Color.luxeEcru.opacity(0.3)).frame(width: 40, height: 4).padding(.top, 10)
                    Text("THE VIRTUAL FITTING").font(.system(size: 14, weight: .black)).tracking(3).padding(.top, 10).foregroundColor(Color.luxeEcru)
                }
                
                if let uiImage = generatedImage {
                    Image(uiImage: uiImage).resizable().aspectRatio(contentMode: .fill)
                        .frame(width: UIScreen.main.bounds.width * 0.85, height: 400).clipped()
                        .overlay(Rectangle().stroke(Color.luxeEcru.opacity(0.2), lineWidth: 0.5))
                        .shadow(color: Color.luxeFlax.opacity(0.1), radius: 20, x: 0, y: 10)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("REIMAGINE THE SCENE").font(.system(size: 10, weight: .bold)).tracking(1).foregroundColor(Color.luxeEcru)
                    HStack(spacing: 12) {
                        TextField("E.G. A PARISIAN RUNWAY AT NIGHT", text: $backgroundPrompt)
                            .font(.system(size: 13, design: .serif)).italic()
                            .padding(15).background(Color.luxeRichCharcoal).cornerRadius(4).foregroundColor(Color.luxeBeige)
                        
                        Button(action: {
                            Task {
                                isProcessing = true
                                if let uiImage = await backgroundChooser(generatedImage: generatedImage!) { self.generatedImage = uiImage }
                                isProcessing = false
                            }
                        }) {
                            ZStack {
                                if isProcessing { ProgressView().tint(.black) }
                                else { Image(systemName: "sparkles").font(.system(size: 16)) }
                            }.frame(width: 48, height: 48).background(Color.luxeGoldGradient).foregroundColor(.black)
                        }.disabled(isProcessing || backgroundPrompt.isEmpty)
                    }
                }.padding(.horizontal, 25)
                
                Spacer()
                
                Button(action: { isShowingPopup = false }) {
                    Text("CLOSE LOOK").font(.system(size: 12, weight: .black)).tracking(2).foregroundColor(Color.luxeEcru)
                        .frame(maxWidth: .infinity).padding().overlay(Rectangle().stroke(Color.luxeEcru, lineWidth: 1))
                }.padding(.horizontal, 25).padding(.bottom, 30)
            }
            .presentationDetents([.large]).presentationDragIndicator(.hidden).presentationCornerRadius(0)
            .background(fitPickBlack.ignoresSafeArea())
        }
    }
    
    private var instagramStyleLikedView: Text {
        let names = post.safeLikedByNames
        let totalLikes = post.likes
        if names.isEmpty { return Text("\(totalLikes) likes") }
        if names.count == 1 { return Text("Liked by ") + Text(names[0]).bold() }
        let otherCount = totalLikes - 1
        return Text("Liked by ") + Text(names.last ?? "").bold() + Text(" and ") + Text("\(otherCount) \(otherCount == 1 ? "other" : "others")").bold()
    }
    
    nonisolated func backgroundChooser(generatedImage: UIImage) async -> UIImage? {
        let generativeModel = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModel(
            modelName: "gemini-2.5-flash-image",
            generationConfig: GenerationConfig(responseModalities: [.text, .image])
        )

        let prompt: [any PartsRepresentable] = [
            "This is an image that contains no background",
            generatedImage,
            """
            Now, change the background of this image based on the user's description.
            The description: \(await backgroundPrompt).
            Change the pose of the person accordingly.
            """
        ]
        
        do {
            let response = try await generativeModel.generateContent(prompt)
            guard let inlineDataPart = response.inlineDataParts.first,
                  let uiImage = UIImage(data: inlineDataPart.data) else { return nil }
            return uiImage
        } catch { return nil }
    }
    
    func tryFit() async {
        let avatarURLx = await fetchAvatarURL(for: session.email ?? "")
        guard let avatartImage = await downloadImage(from: avatarURLx) else { return }
        let postID = post.id
        let postURL = await fetchPostURL(for: postID)
        guard let postImage = await downloadImage(from: postURL) else { return }
        await tryFitWithAI(avatarURL: avatartImage, postURL: postImage)
    }
    
    @MainActor
    func tryFitWithAI(avatarURL: UIImage, postURL: UIImage) async {
        isProcessing = true
        if let uiImage = await performGeneration(avatarImage: avatarURL, postImage: postURL) {
            self.generatedImage = uiImage
            self.isShowingPopup = true
        }
        isProcessing = false
    }
    
    nonisolated func performGeneration(avatarImage: UIImage, postImage: UIImage) async -> UIImage? {
        let generativeModel = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModel(
            modelName: "gemini-2.5-flash-image",
            generationConfig: GenerationConfig(responseModalities: [.text, .image])
        )

        let prompt: [any PartsRepresentable] = [
            "Image 1 is a person (the avatar). Image 2 contains a specific clothing item.",
            avatarImage,
            postImage,
            """
            Extract the exact clothing seen in Image 2 and render it onto the person in Image 1. 
            Maintain the person's pose, face, and physical characteristics from Image 1, 
            but replace their current outfit with the outfit from Image 2. 
            The final result should be a high-quality, realistic photograph of the person from Image 1 wearing the outfit of Image 2.
            Keep the final output in the center of the image.
            """
        ]

        do {
            let response = try await generativeModel.generateContent(prompt)
            guard let inlineDataPart = response.inlineDataParts.first,
                  let uiImage = UIImage(data: inlineDataPart.data) else { return nil }
            return uiImage
        } catch { return nil }
    }

    func downloadImage(from urlString: String?) async -> UIImage? {
        guard let urlString = urlString, let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch { return nil }
    }
    
    func fetchAvatarURL(for email: String) async -> String? {
        let db = Firestore.firestore()
        let docRef = db.collection("users").document(email)
        do {
            let document = try await docRef.getDocument()
            if document.exists {
                let data = document.data()
                return data?["avatarURL"] as? String
            }
            return nil
        } catch { return nil }
    }
    
    func fetchPostURL(for postID: String) async -> String? {
        let db = Firestore.firestore()
        let docRef = db.collection("socials").document(postID)
        do {
            let document = try await docRef.getDocument()
            if document.exists {
                let data = document.data()
                return data?["imageUrl"] as? String ?? ""
            }
            return nil
        } catch { return nil }
    }
    
    func updateCaption() {
        let db = Firestore.firestore()
        db.collection("socials").document(post.id).updateData([
            "caption": editedCaption
        ]) { error in
            if error == nil {
                withAnimation { isEditingCaption = false }
            }
        }
    }
}
