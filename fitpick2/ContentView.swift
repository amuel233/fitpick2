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
    
    let fitPickGold = Color("fitPickGold")
    let fitPickBlack = Color("fitPickBlack")

    var body: some View {
        NavigationStack {
            ZStack {
                // Apply the theme background globally
                fitPickBlack.ignoresSafeArea()
                
                TabView(selection: $appState.selectedTab) {
                    HomeView()
                        .tabItem { Label("Home", systemImage: "house") }
                        .tag(0)

                    ClosetView()
                        .tabItem { Label("Closet", systemImage: "hanger") }
                        .tag(1)

                    SocialsView()
                        .tabItem { Label("Socials", systemImage: "person.2") }
                        .tag(2)

                    BodyMeasurementView()
                        .tabItem { Label("Body", systemImage: "ruler") }
                        .tag(3)
                }
                .accentColor(fitPickGold) // Sets active tab icon and text to gold
            }
            .toolbar {
                // Global Logout Button
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        auth.logout(appState: appState, session: session)
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
                
                // Display the logged-in user's email
                ToolbarItem(placement: .navigationBarLeading) {
                    if let email = session.email {
                        Text(email)
                            .font(.caption2)
                            .foregroundColor(fitPickGold.opacity(0.8)) // Gold tinted email
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
