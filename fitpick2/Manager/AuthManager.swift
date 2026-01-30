//
//  AuthManager.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 1/23/26.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import LocalAuthentication
import SwiftUI

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    // Track the method so Face ID knows whether to look for a password or a Google session
    @AppStorage("loginMethod") var loginMethod: String = "" // "email" or "google"
    @AppStorage("savedEmail") var savedEmail: String = ""
    @AppStorage("hasLoggedInBefore") var hasLoggedInBefore: Bool = false
    
    @Published var errorMessage: String? = nil
    @Published var showErrorAlert: Bool = false
    
    private let service = "fitpick-auth"
    private let db = Firestore.firestore()

    // MARK: - Email Login
    func login(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            if let error = error {
                self.handleError(error)
                return
            }
            self.handleSuccessfulAuth(email: email, password: password)
        }
    }

    // MARK: - Google Login
    func loginWithGoogle() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let user = user, error == nil {
                self.authenticateWithFirebase(user: user)
            } else {
                self.performFreshGoogleSignIn()
            }
        }
    }

    private func performFreshGoogleSignIn() {
        guard let root = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first else { return }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: root) { result, error in
            if let error = error {
                self.handleError(error)
                return
            }
            guard let user = result?.user else { return }
            self.authenticateWithFirebase(user: user)
        }
    }

    private func authenticateWithFirebase(user: GIDGoogleUser) {
        guard let idToken = user.idToken?.tokenString else { return }
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
        
        Auth.auth().signIn(with: credential) { result, error in
            if let error = error {
                self.handleError(error)
                return
            }
            if let email = result?.user.email {
                self.handleSuccessfulAuth(email: email, password: nil)
            }
        }
    }

    // MARK: - Biometrics
    func loginWithBiometrics() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Log in to FitPick") { success, _ in
                if success {
                    DispatchQueue.main.async {
                        // Check if there's a saved password (Email/Password user)
                        if let data = KeychainHelper.standard.read(service: self.service, account: self.savedEmail),
                           let pass = String(data: data, encoding: .utf8), !pass.isEmpty {
                            self.login(email: self.savedEmail, password: pass)
                        } else if self.loginMethod == "google" {
                            // If no password and method was Google
                            self.loginWithGoogle()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Logout
    func logout() {
        // Always sign out of Firebase to protect the app session
        try? Auth.auth().signOut()
        
        if self.loginMethod == "google" {
            // This keeps the Google account 'cached' so restorePreviousSignIn works silently.
            print("Logged out of Firebase; keeping Google session for silent re-entry.")
        } else {
            // For Email users, we don't need to do anything extra as the keychain persists
        }
        
        // Do NOT clear savedEmail or loginMethod so the Face ID button stays visible
    }

    private func handleSuccessfulAuth(email: String, password: String? = nil) {
        if let password = password, let data = password.data(using: .utf8) {
            KeychainHelper.standard.save(data, service: service, account: email)
            self.loginMethod = "email"
        } else {
            // Google users: clear keychain but remember method
            KeychainHelper.standard.delete(service: service, account: email)
            self.loginMethod = "google"
        }
        
        self.syncUserToFirestore(email: email)
        
        DispatchQueue.main.async {
            self.savedEmail = email
            self.hasLoggedInBefore = true
        }
    }

    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = error.localizedDescription
            self.showErrorAlert = true
        }
    }

    private func syncUserToFirestore(email: String) {
        let userRef = db.collection("users").document(email.lowercased())
        userRef.setData([
            "email": email.lowercased(),
            "lastActive": Timestamp(),
            "hasProfile": true
        ], merge: true)
    }
}
