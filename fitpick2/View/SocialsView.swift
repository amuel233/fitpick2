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
                    // MARK: Header
                    HStack(alignment: .center) {
                        Text("Feed")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(fitPickGold)
                        
                        Spacer()
                        
                        NavigationLink(destination: ProfileView(firestoreManager: firestoreManager)) {
                            if let selfieUrl = firestoreManager.currentUserData?.selfie, !selfieUrl.isEmpty {
                                AsyncImage(url: URL(string: selfieUrl)) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: { ProgressView() }
                                .frame(width: 40, height: 40).clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable().frame(width: 40, height: 40).foregroundColor(fitPickGold)
                            }
                        }
                    }
                    .padding()

                    // MARK: Posts Feed
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
