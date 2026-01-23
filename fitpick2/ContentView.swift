//
//  ContentView.swift
//  fitpick
//
//  Created by Amuel Ryco Nidoy on 1/9/26.
//

import SwiftUI
import CoreData
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default)
    private var items: FetchedResults<Item>
    
    var body: some View {
        TabView(selection: .constant(0)) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)

            ClosetView()
                .tabItem {
                    Label("Closet", systemImage: "hanger")
                }
                .tag(1)

            SocialsView()
                .tabItem {
                    Label("Socials", systemImage: "person.2")
                }
                .tag(2)

            BodyMeasurementView()
                .tabItem {
                    Label("Body Mesaurement", systemImage: "ruler")
                }
                .tag(3)
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
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
                .tabItem { Label("Body Mesaurement", systemImage: "ruler") }
                .tag(3)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.isLoggedIn {
            MainTabView()
        } else {
            LoginView()
        }
    }
}

#Preview {
    LoginView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

