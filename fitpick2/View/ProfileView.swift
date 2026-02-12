//
//  ProfileView.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 2/11/26.
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var firestoreManager: FirestoreManager
    
    // UI States
    @State private var isEditingName = false
    @State private var tempName = ""
    @State private var isEditingBio = false
    @State private var tempBio = ""
    @State private var showCamera = false
    @State private var newSelfie: UIImage? = nil
    @State private var isSaving = false
    
    // Theme Colors
    let fitPickGold = Color("fitPickGold")
    let nameLimit = 15
    let bioLimit = 100
    let columns = [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)]

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            
            // MARK: Header (Selfie & Stats)
            HStack(spacing: 20) {
                Button(action: { showCamera = true }) {
                    ZStack(alignment: .bottomTrailing) {
                        if let selfieUrl = firestoreManager.currentUserData?.selfie, !selfieUrl.isEmpty {
                            AsyncImage(url: URL(string: selfieUrl)) { img in
                                img.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: { ProgressView() }
                            .frame(width: 85, height: 85).clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable().frame(width: 85, height: 85).foregroundColor(.gray.opacity(0.3))
                        }
                        
                        Image(systemName: "pencil.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, fitPickGold)
                            .font(.system(size: 22))
                    }
                }
                
                HStack(spacing: 0) {
                    let myPosts = firestoreManager.posts.filter { $0.userEmail == firestoreManager.currentEmail }
                    
                    // Posts Count
                    StatView(count: myPosts.count, label: "Posts", countColor: .black)
                    
                    // Followers Count
                    NavigationLink(destination: SocialConnectionsView(firestoreManager: firestoreManager, startingTab: 0)) {
                        StatView(count: firestoreManager.followersList.count, label: "Followers", countColor: fitPickGold)
                    }
                    
                    // Following Count
                    NavigationLink(destination: SocialConnectionsView(firestoreManager: firestoreManager, startingTab: 1)) {
                        StatView(count: firestoreManager.currentUserData?.following.count ?? 0, label: "Following", countColor: fitPickGold)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)

            // MARK: Bio Section
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    if isEditingBio {
                        VStack(alignment: .trailing, spacing: 8) {
                            TextField("Say something about yourself...", text: $tempBio, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                            
                            HStack(spacing: 15) {
                                // Cancel Bio Button
                                Button("Cancel") {
                                    isEditingBio = false
                                    tempBio = ""
                                }
                                .foregroundColor(.gray)
                                .font(.system(size: 14, weight: .medium))

                                Button {
                                    isSaving = true
                                    firestoreManager.updateInlineProfile(newUsername: firestoreManager.currentUserData?.username ?? "", newBio: tempBio, newSelfie: nil) { _ in
                                        isEditingBio = false; isSaving = false
                                    }
                                } label: {
                                    Text("Save").foregroundColor(fitPickGold).bold()
                                }
                                .font(.system(size: 14))
                            }
                        }
                    } else {
                        Text(firestoreManager.currentUserData?.bio ?? "Say something about yourself...")
                            .font(.system(size: 14))
                        
                        Button(action: {
                            tempBio = firestoreManager.currentUserData?.bio ?? ""
                            isEditingBio = true
                        }) {
                            Image(systemName: "pencil.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, fitPickGold)
                                .font(.system(size: 14))
                        }
                    }
                }
            }
            .padding(.horizontal)

            Divider().background(Color.gray.opacity(0.2))

            // MARK: Post Grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    let myPosts = firestoreManager.posts.filter { $0.userEmail == firestoreManager.currentEmail }
                    ForEach(myPosts) { post in
                        NavigationLink(destination: MyPostsScrollView(startingPost: post, posts: myPosts, firestoreManager: firestoreManager)) {
                            AsyncImage(url: URL(string: post.imageUrl)) { img in
                                img.resizable().aspectRatio(1, contentMode: .fill)
                            } placeholder: { Rectangle().fill(Color.gray.opacity(0.1)) }
                            .frame(minWidth: 0, maxWidth: .infinity).aspectRatio(1, contentMode: .fit).clipped()
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { hideKeyboard() }
            }
        }
        .background(
            Color.white
                .ignoresSafeArea()
                .onTapGesture { hideKeyboard() }
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    if isEditingName {
                        // Cancel Button (Left of TextField)
                        Button(action: {
                            isEditingName = false
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.gray)
                                .font(.system(size: 14, weight: .bold))
                        }

                        TextField("Name", text: $tempName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                        
                        // Save Button (Right of TextField)
                        Button("Save") {
                            isSaving = true
                            firestoreManager.updateInlineProfile(
                                newUsername: tempName,
                                newBio: firestoreManager.currentUserData?.bio,
                                newSelfie: nil
                            ) { _ in
                                isEditingName = false
                                isSaving = false
                            }
                        }
                        .foregroundColor(fitPickGold)
                        .font(.system(size: 14, weight: .bold))
                        
                    } else {
                        // Default View
                        Text(firestoreManager.currentUserData?.username ?? "Profile")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        
                        Button(action: {
                            tempName = firestoreManager.currentUserData?.username ?? ""
                            isEditingName = true
                        }) {
                            Image(systemName: "pencil.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, fitPickGold)
                                .font(.system(size: 12))
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            FaceCaptureView(selectedImage: $newSelfie)
        }
        .onChange(of: newSelfie) { _, image in
            if let image = image {
                isSaving = true
                firestoreManager.updateInlineProfile(newUsername: firestoreManager.currentUserData?.username ?? "", newBio: firestoreManager.currentUserData?.bio, newSelfie: image) { _ in
                    isSaving = false; newSelfie = nil
                }
            }
        }
    }
}

// MARK: - Helper Views & Extensions

struct StatView: View {
    let count: Int
    let label: String
    let countColor: Color
    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)").font(.system(size: 16, weight: .bold)).foregroundColor(countColor)
            Text(label).font(.system(size: 12)).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MyPostsScrollView: View {
    let startingPost: SocialsPost
    let posts: [SocialsPost]
    @ObservedObject var firestoreManager: FirestoreManager
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(posts) { post in
                        SocialPostCardView(post: post, goldColor: Color("fitPickGold"), firestoreManager: firestoreManager)
                            .id(post.id)
                    }
                }
            }
            .onAppear {
                proxy.scrollTo(startingPost.id, anchor: .top)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Posts")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
            }
        }
        .background(Color.white)
    }
}

// Keyboard Dismissal Extension
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
