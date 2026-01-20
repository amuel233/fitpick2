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
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            ClosetView()
                .tabItem {
                    Label("Closet", systemImage: "hanger")
                }
            SocialsView()
                .tabItem {
                    Label("Socials", systemImage: "person.2")
                }
            BodyMeasurementView()
                .tabItem {
                    Label("Body Mesaurement", systemImage: "ruler")
                }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            ClosetView()
                .tabItem {
                    Label("Closet", systemImage: "hanger")
                }

            SocialsView()
                .tabItem {
                    Label("Socials", systemImage: "person.2")
                }
            BodyMeasurementView()
                .tabItem {
                    Label("Body Mesaurement", systemImage: "ruler")
                }
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

