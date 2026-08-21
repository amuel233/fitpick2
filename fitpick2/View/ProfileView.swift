//
//  ProfileView.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 2/17/26.
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
        
    // Refactored Alert States for LuxeAlert
    @State private var showLuxeAlert = false
    @State private var luxeAlertTitle = ""
    @State private var luxeAlertMessage = ""
    
    // MARK: - Updated Luxe Theme Colors
    let fitPickGold = Color.luxeEcru
    let fitPickBlack = Color.luxeDeepOnyx
    let fitPickDarkGray = Color.luxeRichCharcoal
    
    let nameLimit = 15
    let bioLimit = 100
    let columns = [GridItem(.flexible(), spacing: 1), GridItem(.flexible(), spacing: 1), GridItem(.flexible(), spacing: 1)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // MARK: - HEADER
            VStack(spacing: 20) {
                HStack(alignment: .center, spacing: 25) {
                    Button(action: { showCamera = true }) {
                        ZStack(alignment: .bottomTrailing) {
                            if let selfieUrl = firestoreManager.currentUserData?.selfie, !selfieUrl.isEmpty {
                                AsyncImage(url: URL(string: selfieUrl)) { img in
                                    img.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: { Color.luxeRichCharcoal }
                                .frame(width: 100, height: 100).clipShape(Circle())
                                .overlay(Circle().stroke(Color.luxeGoldGradient, lineWidth: 1.5))
                                .shadow(color: Color.luxeFlax.opacity(0.2), radius: 10, x: 0, y: 5)
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .frame(width: 100, height: 100)
                                    .foregroundColor(Color.luxeRichCharcoal)
                            }
                            // Icon using Liquid Glass gold button treatment
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .black))
                                .foregroundColor(.black)
                                .frame(width: 28, height: 28)
                                .liquidGlassGoldButton(cornerRadius: 14)
                        }
                    }
                    
                    HStack(spacing: 20) {
                        let myPosts = firestoreManager.posts.filter { $0.userEmail == firestoreManager.currentEmail }
                        FashionStat(count: myPosts.count, label: "LOOKS", goldColor: Color.luxeFlax)
                        NavigationLink(destination: SocialConnectionsView(firestoreManager: firestoreManager, startingTab: 0)) {
                            FashionStat(count: firestoreManager.followersList.count, label: "FANS", goldColor: Color.luxeFlax)
                        }
                        NavigationLink(destination: SocialConnectionsView(firestoreManager: firestoreManager, startingTab: 1)) {
                            FashionStat(count: firestoreManager.currentUserData?.following.count ?? 0, label: "VIBES", goldColor: Color.luxeFlax)
                        }
                    }
                }
                .padding(.top, 10)
                
                // MARK: - IDENTITY SECTION
                VStack(alignment: .leading, spacing: 14) {
                    
                    // 1. USERNAME LINE
                    VStack(alignment: .leading, spacing: 4) {
                        if isEditingName {
                            VStack(alignment: .trailing, spacing: 10) {
                                TextField("Your handle...", text: $tempName)
                                    .font(.system(size: 16, weight: .black))
                                    .tracking(2)
                                    .padding(12)
                                    .foregroundColor(.luxeBeige)
                                    .liquidGlassPill(cornerRadius: 12)
                                
                                HStack(spacing: 10) {
                                    LiquidGlassActionButton(title: "CANCEL", textColor: Color.luxeBeige.opacity(0.75), width: 76) {
                                        withAnimation { isEditingName = false }
                                    }
                                    LiquidGlassActionButton(title: "SAVE", isProminent: true, width: 76) {
                                        saveProfileUpdate(newName: tempName, newBio: firestoreManager.currentUserData?.bio)
                                    }
                                }
                            }
                        } else {
                            HStack(alignment: .center) {
                                Text(firestoreManager.currentUserData?.username.uppercased() ?? "PROFILE")
                                    .font(.system(size: 16, weight: .black)).tracking(2)
                                    .foregroundColor(Color.luxeBeige)
                                    .shimmer()
                                Spacer()
                                LiquidGlassActionButton(title: "EDIT", textColor: Color.luxeFlax, width: 64, height: 28) {
                                    tempName = firestoreManager.currentUserData?.username ?? ""
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { isEditingName = true }
                                }
                            }
                            .frame(height: 28)
                        }
                    }
                    
                    // 2. BIO LINE
                    VStack(alignment: .leading, spacing: 4) {
                        if isEditingBio {
                            VStack(alignment: .trailing, spacing: 10) {
                                ZStack(alignment: .bottomTrailing) {
                                    TextField("Add a bio...", text: $tempBio, axis: .vertical)
                                        .font(.system(size: 14, design: .serif))
                                        .italic()
                                        .padding(12)
                                        .foregroundColor(.luxeBeige)
                                        .liquidGlassPill(cornerRadius: 12)
                                    Text("\(tempBio.count)/100").font(.system(size: 9, weight: .bold)).foregroundColor(.gray).padding(8)
                                }
                                HStack(spacing: 10) {
                                    LiquidGlassActionButton(title: "CANCEL", textColor: Color.luxeBeige.opacity(0.75), width: 76) {
                                        withAnimation { isEditingBio = false }
                                    }
                                    LiquidGlassActionButton(title: "SAVE", isProminent: true, width: 76) {
                                        isSaving = true
                                        firestoreManager.updateInlineProfile(newUsername: firestoreManager.currentUserData?.username ?? "", newBio: tempBio, newSelfie: nil) { _, _ in
                                            withAnimation { isEditingBio = false }; isSaving = false
                                        }
                                    }
                                }
                            }
                        } else {
                            HStack(alignment: .top) {
                                Text(firestoreManager.currentUserData?.bio ?? "No statement yet.")
                                    .font(.system(size: 14, weight: .regular, design: .serif))
                                    .italic()
                                    .foregroundColor(Color.luxeBeige.opacity(0.7))
                                Spacer()
                                if !isEditingName {
                                    LiquidGlassActionButton(title: "EDIT", textColor: Color.luxeFlax, width: 64, height: 28) {
                                        tempBio = firestoreManager.currentUserData?.bio ?? ""
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { isEditingBio = true }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 25)
            
            // MARK: - LOOKBOOK GRID
            Rectangle().fill(Color.luxeEcru.opacity(0.2)).frame(height: 1)
            HStack {
                Text("LOOKBOOK").font(.system(size: 12, weight: .black)).tracking(3)
                    .foregroundColor(Color.luxeEcru)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 1) {
                    let myPosts = firestoreManager.posts.filter { $0.userEmail == firestoreManager.currentEmail }
                    ForEach(myPosts) { post in
                        NavigationLink(destination: MyPostsScrollView(startingPost: post, posts: myPosts, firestoreManager: firestoreManager)) {
                            AsyncImage(url: URL(string: post.imageUrl)) { img in
                                img.resizable().aspectRatio(1, contentMode: .fill)
                            } placeholder: { Rectangle().fill(Color.luxeRichCharcoal) }.clipped()
                        }
                    }
                }
            }
        }
        .background {
            LiquidGlassBackgroundView()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("MY PROFILE").font(.system(size: 14, weight: .black)).tracking(3).foregroundColor(Color.luxeEcru)
            }
        }
        .luxeAlert(
            isPresented: $showLuxeAlert,
            title: luxeAlertTitle,
            message: luxeAlertMessage,
            confirmTitle: "UNDERSTOOD",
            onConfirm: { showLuxeAlert = false }
        )
        .fullScreenCover(isPresented: $showCamera) { FaceCaptureView(selectedImage: $newSelfie) }
    }
    
    private func saveProfileUpdate(newName: String, newBio: String?) {
            isSaving = true
            
            firestoreManager.updateInlineProfile(
                newUsername: newName,
                newBio: newBio,
                newSelfie: nil
            ) { success, errorMessage in
                isSaving = false
                
                if success {
                    withAnimation {
                        isEditingName = false
                        isEditingBio = false
                    }
                } else {
                    // If updateInlineProfile returns an error (like "Username is already taken.")
                    // We display it using the Luxe style
                    luxeAlertTitle = "IDENTITY ERROR"
                    luxeAlertMessage = errorMessage ?? "An unexpected error occurred in the vault."
                    showLuxeAlert = true
                }
            }
        }
}

// MARK: - SUBVIEWS (LOGIC RETAINED)

struct FashionStat: View {
    let count: Int; let label: String
    let goldColor: Color
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)").font(.system(size: 18, weight: .bold)).foregroundColor(.luxeBeige)
            Text(label).font(.system(size: 10, weight: .black)).tracking(1).foregroundColor(goldColor)
        }
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
                        SocialPostCardView(post: post, goldColor: Color.luxeEcru, firestoreManager: firestoreManager)
                            .id(post.id)
                    }
                }
            }
            .background {
                LiquidGlassBackgroundView()
            }
            .onAppear { proxy.scrollTo(startingPost.id, anchor: .top) }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
