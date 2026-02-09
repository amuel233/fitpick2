//
//  SocialPostCardView.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 1/27/26.
//

import SwiftUI

struct SocialPostCardView: View {
    let post: SocialsPost
    let goldColor: Color
    
    @ObservedObject var firestoreManager: FirestoreManager
    @State private var isExpanded: Bool = false
    @State private var showingDeleteAlert = false

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
            }
            .padding(.horizontal)

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
}
