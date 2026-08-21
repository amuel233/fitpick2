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
        // --- LUXURY LIQUID GLASS TAB BAR STYLING ---
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        
        // Frosted glass base instead of opaque black, so the ambient
        // background glow shows through the bar like the rest of the UI
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        
        // Specular top hairline to echo the glass card border
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.12)
        
        // iOS draws its own highlight pill behind the selected tab icon by
        // default, which uses a system tint that doesn't match our custom
        // blur — that mismatch is what causes the "non-uniform" patch under
        // the selected tab. Clearing it lets our blur be the only background.
        appearance.selectionIndicatorTintColor = .clear
        
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
            // Background of the entire app: Liquid Glass ambient background
            // (deep base + spotlight gradient + GPU-rendered ambient orbs)
            LiquidGlassBackgroundView()
            
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
                    }
                    .liquidGlassGoldButton(cornerRadius: 18)
                    .clipShape(Circle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
            }
        }
    }
}
