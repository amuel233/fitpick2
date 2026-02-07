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
        .animation(.easeInOut, value: appState.isLoggedIn)
    }
}

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var session: UserSession
    @StateObject private var auth = AuthManager.shared
    @State private var showLogoutModal = false

    let fitPickGold = Color("fitPickGold")
    let fitPickBlack = Color("fitPickBlack")

    var body: some View {
        ZStack {
            TabView(selection: $appState.selectedTab) {
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

                // Invisible tab that acts as a trigger
                Color.clear
                    .tabItem { Label("Logout", systemImage: "rectangle.portrait.and.arrow.right") }
                    .tag(4)
            }
            .accentColor(fitPickGold)
            .onChange(of: appState.selectedTab) { _, newValue in
                if newValue == 4 {
                    showLogoutModal = true
                }
            }

            // Custom Gold & White Logout Modal
            if showLogoutModal {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        closeModal()
                    }

                VStack(spacing: 20) {
                    Image(systemName: "door.right.hand.open")
                        .font(.system(size: 50))
                        .foregroundColor(fitPickGold)
                    
                    Text("Logging out?")
                        .font(.title2.bold())
                        .foregroundColor(.black)

                    if let email = session.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }

                    VStack(spacing: 12) {
                        Button(action: {
                            appState.selectedTab = 0
                            auth.logout()
                        }) {
                            Text("Confirm Logout")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(fitPickGold)
                                .cornerRadius(10)
                        }

                        Button(action: {
                            closeModal()
                        }) {
                            Text("Cancel")
                                .fontWeight(.semibold)
                                .foregroundColor(fitPickGold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(fitPickGold, lineWidth: 2)
                                )
                        }
                    }
                }
                .padding(30)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(radius: 20)
                .padding(.horizontal, 40)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(), value: showLogoutModal)
    }

    private func closeModal() {
        showLogoutModal = false
        // Snap back to the previous tab so the logout tab isn't highlighted
        appState.selectedTab = 0
    }
}
