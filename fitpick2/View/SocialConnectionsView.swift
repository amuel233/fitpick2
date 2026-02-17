import SwiftUI

struct SocialConnectionsView: View {
    @ObservedObject var firestoreManager: FirestoreManager
    @State private var selectedTab: Int
    @State private var showFollowRequiredAlert = false
    @State private var pendingUser: User?

    init(firestoreManager: FirestoreManager, startingTab: Int = 0) {
        self.firestoreManager = firestoreManager
        self._selectedTab = State(initialValue: startingTab)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // --- CUSTOM EDITORIAL TABS ---
            HStack(spacing: 50) {
                TabButton(title: "FANS", isSelected: selectedTab == 0) { selectedTab = 0 }
                TabButton(title: "VIBES", isSelected: selectedTab == 1) { selectedTab = 1 }
            }
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            if currentList.isEmpty {
                emptyStateView
            } else {
                List(currentList) { user in
                    let isFollowing = firestoreManager.currentUserData?.following.contains(user.id) ?? false
                    
                    ZStack {
                        userRow(user: user, isFollowing: isFollowing)
                        
                        if isFollowing {
                            NavigationLink(destination: ClosetView(targetUserEmail: user.id, targetUsername: user.username)) {
                                EmptyView()
                            }
                            .opacity(0)
                        } else {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    pendingUser = user
                                    showFollowRequiredAlert = true
                                }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Color.luxeEcru.opacity(0.2))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background {
            ZStack {
                Color.luxeDeepOnyx.ignoresSafeArea()
                Color.luxeSpotlightGradient.ignoresSafeArea()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("CONNECTIONS").font(.system(size: 14, weight: .black)).tracking(3).foregroundColor(Color.luxeEcru)
            }
        }
        // --- INTEGRATED LUXE ALERT ---
        .luxeAlert(
            isPresented: $showFollowRequiredAlert,
            title: "RESTRICTED ACCESS",
            message: "Pardon the intrusion, but you'll need to follow \(pendingUser?.username ?? "this user") to peek inside their closet.",
            confirmTitle: "JOIN THE CLUB",
            cancelTitle: "BACK",
            onConfirm: {
                showFollowRequiredAlert = false
            }
        )
    }
    
    @ViewBuilder
    private func userRow(user: User, isFollowing: Bool) -> some View {
        HStack(spacing: 15) {
            if let url = URL(string: user.selfie), !user.selfie.isEmpty {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.luxeRichCharcoal
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.luxeEcru.opacity(0.3), lineWidth: 1))
            } else {
                Circle()
                    .fill(Color.luxeRichCharcoal)
                    .frame(width: 48, height: 48)
                    .overlay(Text(user.username.prefix(1).uppercased()).foregroundColor(.luxeBeige))
            }

            Text(user.username.uppercased())
                .font(.system(size: 13, weight: .bold))
                .tracking(1.5)
                .foregroundColor(.luxeBeige)
                .lineLimit(1)
            
            Spacer()
            
            Button(action: {
                firestoreManager.toggleFollow(currentEmail: firestoreManager.currentEmail ?? "", targetEmail: user.id, isFollowing: isFollowing)
            }) {
                Text(isFollowing ? "FOLLOWING" : "FOLLOW BACK")
                    .font(.system(size: 10, weight: .black))
                    .padding(.vertical, 8)
                    .frame(width: 110)
                    .background(isFollowing ? Color.clear : Color.luxeEcru)
                    .foregroundColor(isFollowing ? .luxeEcru : .luxeBlack)
                    .border(Color.luxeEcru, width: 1)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }

    private var emptyStateView: some View {
        VStack {
            Spacer()
            Image(systemName: selectedTab == 0 ? "person.2.fill" : "sparkles")
                .font(.system(size: 30))
                .foregroundStyle(Color.luxeGoldGradient)
                .opacity(0.6)
            Text(selectedTab == 0 ? "No fans yet." : "You haven't caught any vibes yet.")
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundColor(.luxeBeige.opacity(0.6))
                .padding(.top, 12)
            Spacer()
        }
    }
    
    private var currentList: [User] {
        selectedTab == 0 ? firestoreManager.followersList : firestoreManager.followingList
    }
}

// Keep the TabButton for this view
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: { withAnimation(.easeInOut) { action() } }) {
            VStack(spacing: 8) {
                Text(title).font(.system(size: 12, weight: .black)).tracking(2.5)
                    .foregroundColor(isSelected ? .luxeBeige : .gray.opacity(0.5))
                Rectangle().fill(isSelected ? Color.luxeEcru : Color.clear)
                    .frame(width: isSelected ? 40 : 0, height: 2)
            }
        }
    }
}
