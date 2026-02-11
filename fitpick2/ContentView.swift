//
//  ContentView.swift
//  fitpick
//
//  Created by Amuel Ryco Nidoy on 1/9/26.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.snappy(duration: 0.2), value: appState.isLoggedIn)
    }
}

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var session: UserSession
    @StateObject private var auth = AuthManager.shared
    @State private var showLogoutModal = false
    
    let fitPickGold = Color("fitPickGold")
    let fitPickOffWhite = Color(red: 245/255, green: 245/255, blue: 247/255)

    var body: some View {
        ZStack(alignment: .top) {
            fitPickOffWhite.ignoresSafeArea()
            
            TabView(selection: $appState.selectedTab) {
                // Each view handles its own internal navigation if needed
                HomeView()
                    .tabItem { Label("Home", systemImage: "house") }
                    .tag(0)

                BodyMeasurementView()
                    .tabItem { Label("Body Measurement", systemImage: "ruler") }
                    .tag(1)
                
                ClosetView()
                    .tabItem { Label("Closet", systemImage: "hanger") }
                    .tag(2)
                
                SocialsView()
                    .tabItem { Label("Socials", systemImage: "person.2") }
                    .tag(3)
            }
            .accentColor(fitPickGold)

            // MARK: - Floating Logout Button
            if appState.selectedTab == 0 {
                HStack {
                    Spacer()
                    Button(action: { showLogoutModal = true }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(fitPickGold)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
            }

            if showLogoutModal {
                logoutModalOverlay
            }
        }
    }

    private var logoutModalOverlay: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
                .onTapGesture { withAnimation { showLogoutModal = false } }

            VStack(spacing: 25) {
                Image(systemName: "door.right.hand.open")
                    .font(.system(size: 60)).foregroundColor(fitPickGold)
                
                VStack(spacing: 8) {
                    Text("Logging out?").font(.title.bold())
                    if let email = session.email {
                        Text(email).font(.subheadline).foregroundColor(.gray)
                    }
                }

                VStack(spacing: 16) {
                    Button("Confirm Logout") {
                        showLogoutModal = false
                        auth.logout()
                    }
                    .fontWeight(.bold).foregroundColor(.white).frame(maxWidth: .infinity)
                    .padding().background(fitPickGold).cornerRadius(12)

                    Button("Cancel") { showLogoutModal = false }
                        .fontWeight(.semibold).foregroundColor(fitPickGold).frame(maxWidth: .infinity)
                        .padding().overlay(RoundedRectangle(cornerRadius: 12).stroke(fitPickGold, lineWidth: 1))
                }
                .padding(.horizontal, 40)
            }
            .padding(30).background(Color.white).cornerRadius(24).padding(.horizontal, 30)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}
