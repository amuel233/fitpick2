//
//  fitpickApp.swift
//  fitpick
//
//  Created by Amuel Ryco Nidoy on 1/9/26.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import FirebaseFirestore
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
            Messaging.messaging().apnsToken = deviceToken
        }
}

@main
struct fitpick2App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()
    @StateObject private var session = UserSession()
    
    private let reminderService = WardrobeReminderService()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(session)
                .onAppear {
                    // Link the session to appState
                    session.linkAppState(appState)
                    
                    // Request Notification Permissions
                    // This triggers the FCM Token generation and the 'wardrobe_reminders' subscription
                    NotificationManager.shared.requestPermissions()
                    
                    // Run the Wardrobe + Calendar Check
                    // This calls LocalCalendarManager and FirestoreManager
                    // We wrap it in a slight delay to ensure the database and session are stable
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        reminderService.runReminderCheck()
                    }
                }
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var selectedTab: Int = 0
    init() { self.isLoggedIn = Auth.auth().currentUser != nil }
}

class UserSession: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var email: String? = Auth.auth().currentUser?.email
    @Published var username: String = "Loading..."
    
    private var db = Firestore.firestore()
    private var handler: AuthStateDidChangeListenerHandle?
    private var userListener: ListenerRegistration?
    private var appState: AppState?

    init() {
        listenToAuthChanges()
    }
    
    func linkAppState(_ appState: AppState) {
        self.appState = appState
    }
    
    func listenToAuthChanges() {
        handler = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            DispatchQueue.main.async {
                if let user = user {
                    self?.isLoggedIn = true
                    self?.email = user.email
                    // This is the trigger that gets you past the LoginView
                    self?.appState?.isLoggedIn = true
                    self?.fetchFirestoreUsername(userId: user.email ?? "")
                } else {
                    self?.isLoggedIn = false
                    self?.email = nil
                    self?.appState?.isLoggedIn = false
                    self?.userListener?.remove()
                }
            }
        }
    }
    
    private func fetchFirestoreUsername(userId: String) {
        userListener?.remove()
        
        // Ensure we use lowercase for document IDs to match AuthManager sync
        userListener = db.collection("users").document(userId.lowercased()).addSnapshotListener { [weak self] snapshot, error in
            if let document = snapshot, document.exists {
                let data = document.data()
                self?.username = data?["username"] as? String ?? "User"
            } else {
                // Fallback for new users before their Firestore doc is created
                self?.username = userId.components(separatedBy: "@").first ?? "User"
            }
        }
    }
}
