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
    
    @EnvironmentObject var session: UserSession
    @StateObject private var firestoreManager = FirestoreManager()
    
    @State private var fetchedUsername: String = "Loading..."
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text(fetchedUsername)
                .font(.headline)
                .foregroundColor(goldColor)
                .padding(.horizontal)
            
            // Image Section
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: UIScreen.main.bounds.width - 32, height: 400)
                
                AsyncImage(url: URL(string: post.imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: UIScreen.main.bounds.width - 32, height: 400)
                            .clipped()
                            .cornerRadius(12)
                            .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                    
                    case .failure:
                        VStack(spacing: 8) {
                            Image(systemName: "wifi.exclamationmark")
                            Text("Connection Error").font(.caption2)
                        }
                        .foregroundColor(.gray)
                    
                    case .empty:
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(goldColor)
                                .scaleEffect(1.5)
                            
                            Text("Curating looks...")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(goldColor.opacity(0.6))
                                .textCase(.uppercase)
                        }
                        
                    @unknown default:
                        EmptyView()
                    }
                }
                
                // AI Overlay
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            // Add trigger for AI Logic here
                        }) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1.5))
                        }
                        .padding(12)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal)

            // Interaction Section
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Button(action: {
                        if let email = session.email {
                            firestoreManager.toggleLike(post: post, userEmail: email, username: session.username)
                        }
                    }) {
                        Image(systemName: post.safeLikedBy.contains(session.email ?? "") ? "heart.fill" : "heart")
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
                    VStack(alignment: .leading, spacing: 2) {
                        (Text(fetchedUsername).bold().foregroundColor(goldColor) +
                         Text(" ") +
                         Text(post.caption).foregroundColor(.black))
                            .font(.subheadline)
                            .lineLimit(isExpanded ? nil : 2)
                    }
                }

                Text(post.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.top, 2)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 10)
        .onAppear {
            firestoreManager.fetchUsername(for: post.userEmail) { name in
                self.fetchedUsername = name
            }
        }
    }
    
    // Bolded Liked-By Logic
    private var instagramStyleLikedView: Text {
        let names = post.safeLikedByNames
        let totalLikes = post.likes
        
        if names.isEmpty {
            return Text("\(totalLikes) likes")
        }
        
        if names.count == 1 {
            return Text("Liked by ") + Text(names[0]).bold()
        }
        
        let otherCount = totalLikes - 1
        return Text("Liked by ") +
               Text(names.last ?? "").bold() +
               Text(" and ") +
               Text("\(otherCount) \(otherCount == 1 ? "other" : "others")").bold()
    }
}
