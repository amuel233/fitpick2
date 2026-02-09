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
    
    @State private var generatedImage: UIImage?
    @State private var isShowingPopup = false
    @State private var isProcessing = false

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
                    // DELETE BUTTON: Only visible if you are the owner
                    Button(action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(goldColor.opacity(0.8))
                            .padding(8)
                            .background(goldColor.opacity(0.1))
                            .clipShape(Circle())
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
                    // TODO: ADD LOGIC HERE
                    
                    Task {
                            await tryFit()
                        }
                    
                }) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .bold))
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .shadow(radius: 5)
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
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 300)
                                    .cornerRadius(12)
                            }
                            
                            Button("Close") {
                                isShowingPopup = false
                            }
                            .padding()
                        }
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
                
                if !post.caption.isEmpty {
                    (Text(post.username).bold().foregroundColor(goldColor) + Text(" ") + Text(post.caption).foregroundColor(.black))
                        .font(.subheadline)
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
            let task = Task { () -> UIImage? in
            let ai = FirebaseAI.firebaseAI(backend: .googleAI())
            let model = ai.imagenModel(modelName: "imagen-4.0-generate-001")
            
            let prompt = """
            
            Persona: You are an expert Virtual Stylist and Image Synthesis engine.
            Task: Perform a 3D "Virtual Try-On" by transferring clothing from a source image to a target subject.
            Steps:
            1. Analyze Source: Extract the complete outfit (including texture, fabric, and fit) from the person in this image: \(postURL), and convert it to 3D.
            2. Analyze Target: Identify the person (the "Avatar") in this image: \(avatarURL). Maintain their physical identity, and body proportions exactly.
            3. Execution: Generate a new image where the Avatar from \(avatarURL) is wearing the exact outfit extracted from \(postURL). Ensure the clothing drapes naturally according to the Avatar's pose. Explicitly only generate the image of the user wearing the exact outfit.
            """
                
            do {
                // 2. 'model' is created and used ONLY here, so it never "crosses" actors
                let response = try await model.generateImages(prompt: prompt)
                
                guard let data = response.images.first?.data else { return nil }
                return UIImage(data: data)
            } catch {
                print("Generation error: \(error)")
                return nil
            }
        }
                if let uiImage = await task.value {
                    self.generatedImage = uiImage
                    self.isShowingPopup = true
                }
            isProcessing = false
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
}
