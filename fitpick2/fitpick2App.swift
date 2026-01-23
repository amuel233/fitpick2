//
//  fitpickApp.swift
//  fitpick
//
//  Created by Amuel Ryco Nidoy on 1/9/26.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
    
    func application(
            _ app: UIApplication,
            open url: URL,
            options: [UIApplication.OpenURLOptionsKey : Any] = [:]
        ) -> Bool {

            return GIDSignIn.sharedInstance.handle(url)
        }
}

@main
struct fitpick2App: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var appState = AppState()
    @StateObject var session = UserSession()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(session)
        }
    }
}

class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var selectedTab: Int = 0 // 0: Home, 1: Closet, 2: Socials, 3: BodyMeasurement
}



