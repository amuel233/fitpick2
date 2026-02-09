//
//  FollowersView.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 2/9/26.
//

import SwiftUI

struct FollowersView: View {
    @ObservedObject var firestoreManager: FirestoreManager
    let fitPickGold = Color("fitPickGold")
    
    var body: some View {
        List(firestoreManager.followersList) { follower in
            HStack {
                // Profile Image (Selfie)
                AsyncImage(url: URL(string: follower.selfie)) { image in
                    image.resizable()
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                Text(follower.username)
                    .font(.headline)
                
                Spacer()
                
                // Optional: Follow Back Button logic
                let isFollowingBack = firestoreManager.currentUserData?.following.contains(follower.id) ?? false
                
                Button(action: {
                    firestoreManager.toggleFollow(
                        currentEmail: firestoreManager.currentEmail ?? "",
                        targetEmail: follower.id,
                        isFollowing: isFollowingBack
                    )
                }) {
                    Text(isFollowingBack ? "Following" : "Follow Back")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isFollowingBack ? Color.gray.opacity(0.2) : fitPickGold)
                        .foregroundColor(isFollowingBack ? .primary : .black)
                        .cornerRadius(15)
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Followers")
        .onAppear {
            firestoreManager.fetchFollowers()
        }
    }
}
