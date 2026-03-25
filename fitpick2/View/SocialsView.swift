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
    
    // Luxe Theme alignment
    let fitPickGold = Color.luxeEcru
    let fitPickBlack = Color.luxeDeepOnyx

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                // Background: Spotlight Gradient
                Color.luxeSpotlightGradient.ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: Header
                    HStack(alignment: .center) {
                        Text("FEED")
                        .font(.system(size: 32, weight: .black))
                        .tracking(2)
                        .foregroundColor(Color.luxeFlax)
                        .modifier(ShimmerEffect())
                        
                        Spacer()
                        
                        NavigationLink(destination: ProfileView(firestoreManager: firestoreManager)) {
                            if let selfieUrl = firestoreManager.currentUserData?.selfie, !selfieUrl.isEmpty {
                                AsyncImage(url: URL(string: selfieUrl)) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: { ProgressView() }
                                .frame(width: 40, height: 40).clipShape(Circle())
                                .overlay(Circle().stroke(Color.luxeFlax, lineWidth: 1))
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable().frame(width: 40, height: 40)
                                    .foregroundColor(Color.luxeFlax)
                            }
                        }
                    }
                    .padding()

                    // MARK: Posts Feed
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(firestoreManager.posts) { post in
                                SocialPostCardView(
                                    post: post,
                                    goldColor: fitPickGold,
                                    firestoreManager: firestoreManager
                                )
                            }
                        }
                    }
                    .background(Color.clear)
                    .refreshable {
                        firestoreManager.fetchSocialPosts()
                        firestoreManager.fetchFollowers()
                        firestoreManager.fetchFollowing()
                    }
                }
                
                // Upload Button with Luxe Gradient
                Button(action: { isShowingUpload = true }) {
                    Image(systemName: "plus")
                        .font(.title.bold())
                        .foregroundColor(.luxeBlack)
                        .frame(width: 60, height: 60)
                        .background(Color.luxeGoldGradient)
                        .clipShape(Circle())
                        .shadow(color: Color.luxeEcru.opacity(0.4), radius: 10)
                }
                .padding(25)
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .fullScreenCover(isPresented: $isShowingUpload) {
                UploadPostView()
            }
        }
    }
}
