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
            VStack(alignment: .leading, spacing: 18) {
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
                        HStack(spacing: 10) {
                            LiquidGlassActionButton(
                                title: isEditingCaption ? "CANCEL" : "EDIT",
                                textColor: isEditingCaption ? Color.luxeBeige.opacity(0.75) : Color.luxeFlax,
                                width: 76
                            ) {
                                editedCaption = post.caption
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isEditingCaption.toggle()
                                }
                            }
                            
                            if !isEditingCaption {
                                LiquidGlassActionButton(
                                    title: "REMOVE",
                                    textColor: Color.luxeBeige.opacity(0.7),
                                    width: 76
                                ) {
                                    withAnimation { showingDeleteAlert = true }
                                }
                            }
                        }
                    } else {
                        LiquidGlassActionButton(
                            title: isFollowing ? "FOLLOWING" : "FOLLOW",
                            isProminent: !isFollowing,
                            width: 100
                        ) {
                            firestoreManager.toggleFollow(currentEmail: myEmail, targetEmail: targetEmail, isFollowing: isFollowing)
                        }
                    }
                }
                .padding(.horizontal, 18)
                
                // --- IMAGE SECTION ---
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: URL(string: post.imageUrl)) { phase in
                        switch phase {
                        case .empty: Rectangle().fill(fitPickDarkGray).frame(width: UIScreen.main.bounds.width - 36, height: 450)
                        case .success(let image): image.resizable().aspectRatio(contentMode: .fill).frame(width: UIScreen.main.bounds.width - 36, height: 450).clipped()
                        case .failure: Rectangle().fill(Color.luxeEcru.opacity(0.1)).frame(width: UIScreen.main.bounds.width - 36, height: 450)
                        @unknown default: EmptyView()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    
                    // "Try fit" sparkles button — the clearest Liquid Glass moment,
                    // floating over live photo content so refraction actually reads.
                    Button(action: { Task { isProcessing = true; await tryFit(); isProcessing = false } }) {
                        ZStack {
                            if isProcessing { ProgressView().tint(.white) }
                            else { Image(systemName: "sparkles").font(.system(size: 18, weight: .bold)) }
                        }
                        .frame(width: 44, height: 44)
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .liquidGlassPill(cornerRadius: 22) // 22 = half of 44pt frame, reads as a circle
                    .padding(12)
                    .disabled(isProcessing)
                }
                .padding(.horizontal, 18)

                // --- LIKES & CAPTION ---
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Button(action: {
                            if let email = firestoreManager.currentEmail {
                                let myUsername = firestoreManager.currentUserData?.username ?? "User"
                                firestoreManager.toggleLike(post: post, userEmail: email, username: myUsername)
                            }
                        }) {
                            Image(systemName: post.safeLikedBy.contains(firestoreManager.currentEmail ?? "") ? "heart.fill" : "heart")
                                .font(.system(size: 20)).foregroundColor(Color.luxeFlax)
                        }
                        .buttonStyle(.plain)
                        if post.likes > 0 { instagramStyleLikedView.font(.system(size: 12, weight: .bold)).foregroundColor(Color.luxeBeige) }
                    }
                    
                    if isEditingCaption {
                        VStack(alignment: .trailing, spacing: 10) {
                            TextField("Edit your statement...", text: $editedCaption, axis: .vertical)
                                .font(.system(size: 15, weight: .regular, design: .serif))
                                .italic()
                                .padding(14)
                                .foregroundColor(Color.luxeBeige)
                                .liquidGlassPill(cornerRadius: 14)
                            LiquidGlassActionButton(title: "SAVE CHANGES", isProminent: true, width: 116) {
                                updateCaption()
                            }
                        }
                    } else if !post.caption.isEmpty {
                        Text(post.caption).font(.system(size: 15, weight: .regular, design: .serif)).italic().lineSpacing(4).foregroundColor(Color.luxeBeige.opacity(0.9))
                    }
                    Text(post.timestamp, style: .relative).font(.system(size: 9, weight: .bold)).tracking(1).foregroundColor(.gray).textCase(.uppercase)
                }
                .padding(.horizontal, 18)
            }
            .padding(.vertical, 18)
            .liquidGlassCard(cornerRadius: 26)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .sheet(isPresented: $isShowingPopup) {
            VirtualFittingView(
                    isShowingPopup: $isShowingPopup,
                    backgroundPrompt: $backgroundPrompt,
                    generatedImage: $generatedImage,
                    isProcessing: $isProcessing,
                    fitPickBlack: fitPickBlack,
                    onGenerate: {
                        Task {
                            isProcessing = true
                            if let uiImage = generatedImage,
                               let newImage = await backgroundChooser(generatedImage: uiImage) {
                                self.generatedImage = newImage
                            }
                            isProcessing = false
                        }
                    }
                )
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
        let generativeModel = FirebaseAI.firebaseAI(backend: .agentPlatform()).generativeModel(
            modelName: "gemini-3-pro-image",
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
        let generativeModel = FirebaseAI.firebaseAI(backend: .agentPlatform()).generativeModel(
            modelName: "gemini-3-pro-image",
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
            Keep the final image output in the center and maximize as needed.
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
