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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // --- HEADER ---
            HStack {
                let myEmail = firestoreManager.currentEmail ?? ""
                let targetEmail = post.userEmail
                // Strictly only true if current user follows the post author
                let isFollowing = firestoreManager.currentUserData?.following.contains(targetEmail) ?? false
                
                // REDIRECTION LOGIC: Strictly for followers only.
                NavigationLink(destination: ClosetView(targetUserEmail: targetEmail, targetUsername: post.username)) {
                    Text(post.username)
                        .font(.headline)
                        .foregroundColor(goldColor)
                        // Ensure the text area is clickable even on transparent parts
                        .contentShape(Rectangle())
                }
                .buttonStyle(BorderlessButtonStyle())
                // This is the key: it is ONLY clickable if isFollowing is true
                .disabled(!isFollowing)
                
                Spacer()
                
                // Action Buttons: Delete for owner, Follow/Unfollow for others
                if myEmail == targetEmail {
                    Menu {
                        Button(action: {
                            editedCaption = post.caption
                            isEditingCaption = true
                        }) {
                            Label("Edit Caption", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive, action: { showingDeleteAlert = true }) {
                            Label("Delete Post", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18))
                            .foregroundColor(goldColor)
                            .padding(8)
                            .contentShape(Rectangle())
                    }
                } else {
                    // Follow Button
                    Button(action: {
                        firestoreManager.toggleFollow(
                            currentEmail: myEmail,
                            targetEmail: targetEmail,
                            isFollowing: isFollowing
                        )
                    }) {
                        Text(isFollowing ? "Unfollow" : "Follow")
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(isFollowing ? Color.clear : goldColor)
                            .foregroundColor(isFollowing ? Color.gray : Color.black)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(goldColor, lineWidth: isFollowing ? 1 : 0))
                            .cornerRadius(6)
                    }
                }
            }
            .padding(.horizontal)
            
            // --- IMAGE SECTION ---
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: post.imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.1))
                            
                            VStack(spacing: 10) {
                                ProgressView()
                                    .tint(goldColor)
                                Text("Fetching latest trends...")
                                    .font(.caption2)
                                    .foregroundColor(goldColor)
                            }
                        }
                        .frame(width: UIScreen.main.bounds.width - 32, height: 400)
                        
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: UIScreen.main.bounds.width - 32, height: 400)
                            .clipped()
                            .cornerRadius(12)
                            
                    case .failure:
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(goldColor.opacity(0.1))
                            
                            VStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.largeTitle)
                                Text("Failed to load photo")
                                    .font(.caption)
                            }
                            .foregroundColor(goldColor)
                        }
                        .frame(width: UIScreen.main.bounds.width - 32, height: 400)
                        
                    @unknown default:
                        EmptyView()
                    }
                }
                
                // AI Button
                Button(action: {
                    print("AI Try On Triggered")
                    Task {
                        isProcessing = true // Start loading
                            await tryFit()
                        isProcessing = false
                        }
                    
                }) {
                    ZStack {
                        if isProcessing {
                            // The Loading Spinner
                            ProgressView()
                                .tint(.white)
                                .controlSize(.regular)
                        } else {
                            // The Original Icon
                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .bold))
                        }
                    }
                    .frame(width: 40, height: 40) // Ensure the button size stays consistent
                    .background(.ultraThinMaterial)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                    .shadow(radius: isProcessing ? 0 : 5)
                }
                .padding(12)
                .disabled(isProcessing)
            }
            .padding(.horizontal)
            .sheet(isPresented: $isShowingPopup) {
                        VStack {
                            Text("AI Generated Result")
                                .font(.headline)
                                .padding()
                            
                            if let uiImage = generatedImage {
                                
                                Spacer() // Pushes image to center
                                
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                                    .cornerRadius(12)
                                    .padding(.horizontal, 20)
                                
                                Spacer()
                            }
                            
                            Text("Describe your background here:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                            TextField("e.g. A sunset at a Paris café", text: $backgroundPrompt)
                            .textFieldStyle(.roundedBorder) // Standard look
                            .frame(width: 280) // Set a fixed width
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)

                            Button(action: {
                                Task {
                                    isProcessing = true // Start loading
                                    if let uiImage = await backgroundChooser(generatedImage: generatedImage!){
                                        self.generatedImage = uiImage
                                        self.isShowingPopup = true
                                    }
                                    isProcessing = false
                                }
                            }) {
                                ZStack {
                                    if isProcessing {
                                        // The Loading Spinner
                                        ProgressView()
                                            .tint(.white)
                                            .controlSize(.regular)
                                    } else {
                                        // The Original Icon
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 18, weight: .bold))
                                    }
                                }
                                .frame(width: 40, height: 40) // Ensure the button size stays consistent
                                .background(.ultraThickMaterial)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: isProcessing ? 0 : 5)
                            }
                            .padding(12)
                            .disabled(isProcessing)

                            
                            Button("Close") {
                                isShowingPopup = false
                            }
                            .buttonStyle(.borderedProminent)
                            .padding()
                        }
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(30) // New in iOS 16.4+
                
                    }.animation(.default, value: isProcessing)

            // --- INTERACTION SECTION ---
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Button(action: {
                        if let email = firestoreManager.currentEmail {
                            let myUsername = firestoreManager.currentUserData?.username ?? "User"
                            firestoreManager.toggleLike(post: post, userEmail: email, username: myUsername)
                        }
                    }) {
                        Image(systemName: post.safeLikedBy.contains(firestoreManager.currentEmail ?? "") ? "heart.fill" : "heart")
                            .font(.system(size: 22))
                            .foregroundColor(goldColor)
                    }
                    
                    if post.likes > 0 {
                        instagramStyleLikedView
                            .font(.subheadline)
                            .foregroundColor(goldColor)
                    }
                    Spacer()
                }
                
                if isEditingCaption {
                    HStack {
                        TextField("Edit caption...", text: $editedCaption)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.subheadline)
                        
                        Button("Save") {
                            updateCaption()
                        }
                        .font(.caption.bold())
                        .foregroundColor(goldColor)
                        
                        Button("Cancel") {
                            isEditingCaption = false
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                    }
                } else if !post.caption.isEmpty {
                    // This is your original caption display
                    (Text(post.username).bold().foregroundColor(goldColor) + Text(" ") + Text(post.caption).foregroundColor(.black))
                        .font(.subheadline)
                        .onTapGesture {
                            // Allows the owner to tap the text to start editing
                            if firestoreManager.currentEmail == post.userEmail {
                                editedCaption = post.caption
                                isEditingCaption = true
                            }
                        }
                }
                
                // Timestamp
                Text(post.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.top, 2)
                    .textCase(.uppercase)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 10)
        // DELETE CONFIRMATION ALERT
        .alert("Delete Post?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                firestoreManager.deletePost(post: post)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently remove your post and the photo from FitPick.")
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

        // Note: Use the UIImage object directly in the array to ensure
        // the AI actually processes the image data.
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
                  let uiImage = UIImage(data: inlineDataPart.data) else {
                return nil
            }
            return uiImage
        } catch {
            print("Generation error: \(error)")
            return nil
        }

    
    }
    
    func tryFit () async {

        let avatarURLx = await fetchAvatarURL(for: session.email ?? "")
        guard let avatartImage = await downloadImage(from: avatarURLx) else { return }
        
        let postID = post.id
        let postURL = await fetchPostURL(for: postID)
        guard let postImage = await downloadImage(from: postURL) else { return }
                
        if let imageURL = postURL {
            print("Success! Image found: \(imageURL)")
            // Update your UI state here
        }
        await tryFitWithAI(avatarURL: avatartImage, postURL: postImage)
    }
    
    
    
    @MainActor
    func tryFitWithAI(avatarURL: UIImage, postURL: UIImage) async {
        isProcessing = true
        
        // We call a separate function to handle the SDK work
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

        // Note: Use the UIImage object directly in the array to ensure
        // the AI actually processes the image data.
        let prompt: [any PartsRepresentable] = [
            "Image 1 is a person (the avatar). Image 2 contains a specific clothing item.",
            avatarImage, // This becomes 'Image 1'
            postImage,   // This becomes 'Image 2'
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
                  let uiImage = UIImage(data: inlineDataPart.data) else {
                return nil
            }
            return uiImage
        } catch {
            print("Generation error: \(error)")
            return nil
        }
    }

      
    func downloadImage(from urlString: String?) async -> UIImage? {
        // 1. Safety check: make sure the URL string isn't empty
        guard let urlString = urlString, let url = URL(string: urlString) else {
            return nil
        }
        
        do {
            // 2. Fetch the data from the URL
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // 3. Convert data to a UIImage
            return UIImage(data: data)
        } catch {
            print("Error downloading image: \(error)")
            return nil
        }
    }
    
    func fetchAvatarURL(for email: String) async -> String? {
        
        let db = Firestore.firestore()
            // Reference: users -> [email]
        let docRef = db.collection("users").document(email)
            
            do {
                let document = try await docRef.getDocument()
                
                if document.exists {
                    // Extract the avatarURL field as a String
                    let data = document.data()
                    let avatarURL = data?["avatarURL"] as? String
                    return avatarURL
                } else {
                    print("Document does not exist")
                    return nil
                }
            } catch {
                print("Error fetching document: \(error)")
                return nil
            }
        }
    
    func fetchPostURL(for postID: String) async -> String? {
        let db = Firestore.firestore()
        let docRef = db.collection("socials").document(postID)
        do {
            let document = try await docRef.getDocument()
            
            if document.exists {
                // In this collection, the field is named "imageUrl"
                let data = document.data()
                return data?["imageUrl"] as? String ?? ""
            } else {
                print("Social post not found")
                return nil
            }
        } catch {
            print("Error fetching post: \(error)")
            return nil
        }
    }
    
    func updateCaption() {
        let db = Firestore.firestore()
        db.collection("socials").document(post.id).updateData([
            "caption": editedCaption
        ]) { error in
            if let error = error {
                print("Error updating caption: \(error.localizedDescription)")
            } else {
                isEditingCaption = false
            }
        }
    }
}
