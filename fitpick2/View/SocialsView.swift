//
//  SocialsView.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 1/27/26.
//

import SwiftUI

struct SocialsView: View {
    @StateObject var firestoreManager = FirestoreManager()
    @EnvironmentObject var session: UserSession
    @State private var isShowingUpload = false
    
    let fitPickGold = Color("fitPickGold")
    let fitPickBlack = Color("fitPickBlack")

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            fitPickBlack.ignoresSafeArea()
            
            // Global State: If no posts exist yet, show a big loader
            if firestoreManager.posts.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                        .tint(fitPickGold)
                        .scaleEffect(2)
                    Text("Refreshing your feed...")
                        .font(.subheadline)
                        .foregroundColor(fitPickGold)
                        .padding(.top, 20)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        Text("Feed")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(fitPickGold)
                            .padding(.horizontal)
                        
                        ForEach(firestoreManager.posts) { post in
                            SocialPostCardView(post: post, goldColor: fitPickGold)
                        }
                    }
                    .padding(.top)
                }
                .refreshable {
                    firestoreManager.fetchSocialPosts()
                }
            }
            
            // Floating Upload Button
            Button(action: { isShowingUpload = true }) {
                Image(systemName: "plus")
                    .font(.title.bold())
                    .foregroundColor(.black)
                    .frame(width: 60, height: 60)
                    .background(fitPickGold)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 5)
            }
            .padding(20)
        }
        .fullScreenCover(isPresented: $isShowingUpload) {
            UploadPostView()
        }
        .onAppear {
            firestoreManager.fetchSocialPosts()
        }
    }
}
