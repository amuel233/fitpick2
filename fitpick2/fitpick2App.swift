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
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate {
    let taskIdentifier = "com.fitpick.wardrobeCheck"
    private let reminderService = WardrobeReminderService()
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = NotificationManager.shared
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func scheduleAppRefresh(at date: Date? = nil) {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        let minDelay = Date(timeIntervalSinceNow: 15 * 60)
        request.earliestBeginDate = date != nil ? max(date!, minDelay) : minDelay
        
        // Create a formatter to show local time instead of UTC
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = .current // This converts UTC to your local clock
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("🚀 Next check scheduled for: \(formatter.string(from: request.earliestBeginDate!))")
        } catch {
            print("❌ Scheduling Error: \(error)")
        }
    }

    func handleAppRefresh(task: BGAppRefreshTask) {
        reminderService.runReminderCheck { nextRun in
            self.scheduleAppRefresh(at: nextRun)
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { task.setTaskCompleted(success: false) }
    }
    
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}

@main
struct fitpick2App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase
    
    @StateObject private var appState = AppState()
    @StateObject private var session = UserSession()
    private let reminderService = WardrobeReminderService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(session)
                .onAppear {
                    session.linkAppState(appState)
                    NotificationManager.shared.requestPermissions()
                }
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .background {
                        delegate.scheduleAppRefresh()
                    }
                    if newPhase == .active {
                        // Log event count immediately when user returns
                        reminderService.runReminderCheck { _ in }
                    }
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
