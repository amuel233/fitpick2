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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // --- HEADER ---
            HStack {
                Text(post.username)
                    .font(.headline)
                    .foregroundColor(goldColor)
                
                Spacer()
                
                if let myEmail = firestoreManager.currentEmail, post.userEmail != myEmail {
                    let isFollowing = firestoreManager.currentUserData?.following.contains(post.userEmail) ?? false
                    
                    Button(action: {
                        print("Follow button tapped for \(post.userEmail)")
                        firestoreManager.toggleFollow(
                            currentEmail: myEmail,
                            targetEmail: post.userEmail,
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
                    .buttonStyle(PlainButtonStyle())
                    .contentShape(Rectangle())
                }
            }
            .padding(.horizontal)
            .zIndex(10)
            
            // --- IMAGE SECTION ---
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: post.imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        // This shows WHILE the image is downloading
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
                        // This shows when the image is READY
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: UIScreen.main.bounds.width - 32, height: 400)
                            .clipped()
                            .cornerRadius(12)
                            
                    case .failure:
                        // This shows if the link is broken or internet fails
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
