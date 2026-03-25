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
    
    // Updated to Luxe Theme Colors
    let fitPickGold = Color.luxeEcru
    let editorBlack = Color.luxeDeepOnyx

    init() {
        // --- LUXURY TAB BAR STYLING ---
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black // Deepest base
        
        // Normal (Unselected) State - Muted Silver
        // A middle ground: lighter than gray, but softer than pure white
        let unselectedColor = UIColor.white.withAlphaComponent(0.4)
        appearance.stackedLayoutAppearance.normal.iconColor = unselectedColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: unselectedColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        
        // Selected State - Luxe Flax Gold
        // Using the hex from your theme (EBD58D) for a premium gold look
        let luxeFlaxUI = UIColor(red: 235/255, green: 213/255, blue: 141/255, alpha: 1.0)
        appearance.stackedLayoutAppearance.selected.iconColor = luxeFlaxUI
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: luxeFlaxUI,
            .font: UIFont.systemFont(ofSize: 10, weight: .bold)
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Background of the entire app: Updated to Spotlight Gradient
            Color.luxeSpotlightGradient.ignoresSafeArea()
            // Ambient Glows: Using Luxe palette colors for soft depth
            GeometryReader { geo in
                ZStack {
                    Circle().fill(Color.luxeEcru).frame(width: 400, height: 400)
                        .blur(radius: 150).opacity(0.08).offset(x: -150, y: -200)
                    Circle().fill(Color.luxeFlax).frame(width: 300, height: 300)
                        .blur(radius: 120).opacity(0.05).offset(x: 200, y: 100)
                }
            }
            
            TabView(selection: $appState.selectedTab) {
                HomeView()
                    .tabItem { Label("HOME", systemImage: "house") }
                    .tag(0)

                BodyMeasurementView()
                    .tabItem { Label("MEASUREMENT", systemImage: "ruler") }
                    .tag(1)
                
                ClosetView()
                    .tabItem { Label("CLOSET", systemImage: "hanger") }
                    .tag(2)
                
                SocialsView()
                    .tabItem { Label("SOCIALS", systemImage: "person.2") }
                    .tag(3)
            }
            .accentColor(fitPickGold)
            .blur(radius: showLogoutModal ? 10 : 0) // Aesthetic editorial blur
            .luxeAlert(
                isPresented: $showLogoutModal,
                title: "LEAVING SO SOON?",
                message: "Your style profile will be safely archived.",
                confirmTitle: "LOGOUT",
                cancelTitle: "STAY CHIC",
                onConfirm: {
                    showLogoutModal = false
                    auth.logout()
                }
            )

            // Branded Logout Trigger (Only on Home)
            if appState.selectedTab == 0 {
                HStack {
                    Spacer()
                    Button(action: { withAnimation { showLogoutModal = true } }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.luxeBlack) // Changed for contrast
                            .padding(10)
                            .background(Color.luxeGoldGradient) // Updated to Luxe Gradient
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
            }
        }
    }
}
