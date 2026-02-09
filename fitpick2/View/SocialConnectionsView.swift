//
//  SocialConnectionsView.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 2/9/26.
//

import SwiftUI

struct SocialConnectionsView: View {
    @ObservedObject var firestoreManager: FirestoreManager
    @State private var selectedTab = 0
    @State private var showFollowRequiredAlert = false
    @State private var pendingUser: User?
    
    let fitPickGold = Color("fitPickGold")
    
    var body: some View {
        VStack {
            Picker("Social", selection: $selectedTab) {
                Text("Followers").tag(0)
                Text("Following").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            if currentList.isEmpty {
                emptyStateView
            } else {
                List(currentList) { user in
                    let isFollowing = firestoreManager.currentUserData?.following.contains(user.id) ?? false
                    
                    if isFollowing {
                        // Redirect to ClosetView if following
                        NavigationLink(destination: ClosetView(targetUserEmail: user.id, targetUsername: user.username)) {
                            userRow(user: user, isFollowing: isFollowing)
                        }
                    } else {
                        // Show alert if NOT following
                        userRow(user: user, isFollowing: isFollowing)
                            .onTapGesture {
                                pendingUser = user
                                showFollowRequiredAlert = true
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(selectedTab == 0 ? "Followers" : "Following")
        .navigationBarTitleDisplayMode(.inline)
        // Follow Required Alert
        .alert("Follow Required", isPresented: $showFollowRequiredAlert, presenting: pendingUser) { user in
            Button("OK", role: .cancel) { }
        } message: { user in
            Text("You must follow \(user.username) to view their closet.")
        }
        .onAppear {
            firestoreManager.fetchFollowers()
            firestoreManager.fetchFollowing()
        }
        .onChange(of: selectedTab) {
            firestoreManager.fetchFollowers()
            firestoreManager.fetchFollowing()
        }
    }
    
    @ViewBuilder
    private func userRow(user: User, isFollowing: Bool) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: user.selfie)) { image in
                image.resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle().fill(Color.gray.opacity(0.2))
                    .overlay(Image(systemName: "person.fill").foregroundColor(.white))
            }
            .frame(width: 45, height: 45)
            .clipShape(Circle())
            
            Text(user.username)
                .font(.system(.body, design: .rounded))
                .fontWeight(.medium)
            
            Spacer()
            
            // The button now only shows Follow/Following logic for both tabs
            actionButton(user: user, isFollowing: isFollowing)
        }
        .contentShape(Rectangle())
        .listRowSeparator(.hidden)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func actionButton(user: User, isFollowing: Bool) -> some View {
        Button(action: {
            firestoreManager.toggleFollow(
                currentEmail: firestoreManager.currentEmail ?? "",
                targetEmail: user.id,
                isFollowing: isFollowing
            )
        }) {
            Text(isFollowing ? "Following" : "Follow Back")
                .font(.caption.bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isFollowing ? Color.gray.opacity(0.1) : fitPickGold)
                .foregroundColor(isFollowing ? .primary : .black)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private var emptyStateView: some View {
        VStack {
            Spacer()
            Image(systemName: selectedTab == 0 ? "person.2.slash" : "person.badge.plus")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text(selectedTab == 0 ? "No followers yet." : "You aren't following anyone.")
                .foregroundColor(.secondary)
                .padding(.top, 8)
            Spacer()
        }
    }

    private var currentList: [User] {
        selectedTab == 0 ? firestoreManager.followersList : firestoreManager.followingList
    }
}
