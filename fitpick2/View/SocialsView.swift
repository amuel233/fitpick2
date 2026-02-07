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
                    HStack {
                        Text("Feed")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(fitPickGold)
                        Spacer()
                    }
                    .padding()

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
                    .refreshable { firestoreManager.fetchSocialPosts() }
                }
                
                // Upload Button
                Button(action: { isShowingUpload = true }) {
                    Image(systemName: "plus").font(.title.bold()).foregroundColor(.black)
                        .frame(width: 60, height: 60).background(fitPickGold).clipShape(Circle())
                }
                .padding(25)
            }
            .fullScreenCover(isPresented: $isShowingUpload) { UploadPostView() }
        }
    }
}
