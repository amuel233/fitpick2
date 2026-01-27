//
//  AuthManager.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 1/23/26.

import Foundation
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import LocalAuthentication
import SwiftUI

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    var onLoginSuccess: (() -> Void)?
    
    @AppStorage("savedEmail") var savedEmail: String = ""
    @AppStorage("hasLoggedInBefore") var hasLoggedInBefore: Bool = false
    
    private let service = "fitpick-auth"
    private let db = Firestore.firestore()

    func login(email: String, password: String, session: UserSession) {
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            if error == nil {
                DispatchQueue.main.async { session.email = email }
                self.handleSuccessfulAuth(email: email, password: password)
            }
        }
    }

    func loginWithGoogle(session: UserSession) {
        guard let root = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first?.windows.first?.rootViewController else { return }
        GIDSignIn.sharedInstance.signIn(withPresenting: root) { result, _ in
            if let email = result?.user.profile?.email {
                DispatchQueue.main.async { session.email = email }
                self.handleSuccessfulAuth(email: email)
            }
        }
    }

    func loginWithBiometrics(session: UserSession) {
        let context = LAContext()
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Log in") { success, _ in
                if success, let data = KeychainHelper.standard.read(service: self.service, account: self.savedEmail),
                   let pass = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async { self.login(email: self.savedEmail, password: pass, session: session) }
                }
            }
        }
    }

    func logout(appState: AppState, session: UserSession) {
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        DispatchQueue.main.async {
            session.email = nil
            appState.isLoggedIn = false
        }
    }

    private func handleSuccessfulAuth(email: String, password: String? = nil) {
        // 1. Save to Keychain for Face ID
        if let password = password, let data = password.data(using: .utf8) {
            KeychainHelper.standard.save(data, service: service, account: email)
        }
        
        // 2. Sync to Firestore (Bringing this back)
        self.syncUserToFirestore(email: email)
        
        DispatchQueue.main.async {
            self.savedEmail = email
            self.hasLoggedInBefore = true
            self.onLoginSuccess?()
        }
    }

    // Firestore Sync Logic
    private func syncUserToFirestore(email: String) {
        let userRef = db.collection("users").document(email.lowercased())
        userRef.setData([
            "email": email.lowercased(),
            "lastActive": Timestamp(),
            "hasProfile": true // Placeholder for your profile logic
        ], merge: true) { error in
            if let error = error {
                print("Firestore Sync Error: \(error.localizedDescription)")
            } else {
                print("Successfully synced user: \(email)")
            }
        }
    }
}
