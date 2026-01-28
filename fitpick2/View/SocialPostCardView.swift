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
            
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: post.imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                            .frame(width: UIScreen.main.bounds.width - 32, height: 400)
                            .clipped().cornerRadius(12)
                    case .failure:
                        RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.2))
                            .frame(height: 400).overlay(Image(systemName: "photo").foregroundColor(.gray))
                    case .empty:
                        ProgressView().frame(maxWidth: .infinity, minHeight: 400)
                    @unknown default:
                        EmptyView()
                    }
                }
                
                Button(action: {
                    print("AI Try-on triggered for: \(post.imageUrl)")
                    //Add logic here
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
            .padding(.horizontal)

            //Interaction & Caption Area
            VStack(alignment: .leading, spacing: 6) {
                // Like Bar
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
                        Text(getInstagramStyleLikedText())
                            .font(.subheadline)
                            .foregroundColor(.fitPickGold)
                    }
                    
                    Spacer()
                }
                
                //Caption & Likes
                if !post.caption.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        (Text(fetchedUsername).bold().foregroundColor(goldColor) +
                         Text(" ") +
                         Text(post.caption).foregroundColor(.black))
                            .font(.subheadline)
                            .lineLimit(isExpanded ? nil : 2)
                        
                        if !isExpanded && post.caption.count > 60 {
                            Button(action: { withAnimation { isExpanded = true } }) {
                                Text("more")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
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
        .onAppear {
            firestoreManager.fetchUsername(for: post.userEmail) { name in
                self.fetchedUsername = name
            }
        }
    }
    
    private func getInstagramStyleLikedText() -> String {
        let names = post.safeLikedByNames
        let totalLikes = post.likes
        if names.isEmpty { return "\(totalLikes) likes" }
        if names.count == 1 { return "Liked by \(names[0])" }
        return "Liked by \(names.last ?? "") and \(totalLikes - 1) others"
    }
}
