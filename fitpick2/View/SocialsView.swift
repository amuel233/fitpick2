//
//  SocialsView.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 1/27/26.
//

import SwiftUI

struct SocialsView: View {
    @StateObject var firestoreManager = FirestoreManager()
    @State private var isShowingUpload = false
    let fitPickGold = Color("fitPickGold")

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // MARK: - Header with Follower Counts
                    HStack(alignment: .lastTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Feed")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(fitPickGold)
                            
                            // Tapping this navigates to the Followers/Following list
                            NavigationLink(destination: SocialConnectionsView(firestoreManager: firestoreManager)) {
                                HStack(spacing: 15) {
                                    HStack(spacing: 4) {
                                        Text("\(firestoreManager.followersList.count)")
                                            .fontWeight(.bold)
                                        Text("Followers")
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack(spacing: 4) {
                                        Text("\(firestoreManager.currentUserData?.following.count ?? 0)")
                                            .fontWeight(.bold)
                                        Text("Following")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .font(.system(size: 14, design: .rounded))
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding()

                    // MARK: - Posts Feed
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(firestoreManager.posts) { post in
                                SocialPostCardView(
                                    post: post,
                                    goldColor: fitPickGold,
                                    firestoreManager: firestoreManager
                                )
                            }
                        }
                    }
                    .refreshable {
                        firestoreManager.fetchSocialPosts()
                        firestoreManager.fetchFollowers()
                        firestoreManager.fetchFollowing()
                    }
                }
                
                // Upload Button
                Button(action: { isShowingUpload = true }) {
                    Image(systemName: "plus")
                        .font(.title.bold())
                        .foregroundColor(.black)
                        .frame(width: 60, height: 60)
                        .background(fitPickGold)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding(25)
            }
            .fullScreenCover(isPresented: $isShowingUpload) {
                UploadPostView()
            }
        }
    }
}
