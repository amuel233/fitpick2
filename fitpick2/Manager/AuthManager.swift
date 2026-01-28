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
    
    @AppStorage("savedEmail") var savedEmail: String = ""
    @AppStorage("hasLoggedInBefore") var hasLoggedInBefore: Bool = false
    
    private let service = "fitpick-auth"
    private let db = Firestore.firestore()

    func login(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            if let error = error {
                print("Login Error: \(error.localizedDescription)") // This catches the malformed error
                return
            }
            self.handleSuccessfulAuth(email: email, password: password)
        }
    }

    func loginWithGoogle() {
        guard let root = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first?.windows.first?.rootViewController else { return }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: root) { result, error in
            if let error = error {
                print("Google Sign-In Error: \(error.localizedDescription)")
                return
            }
            
            // Get fresh credentials from Google Result
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else { return }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("Firebase Google Auth Error: \(error.localizedDescription)")
                    return
                }
                if let email = authResult?.user.email {
                    self.handleSuccessfulAuth(email: email)
                }
            }
        }
    }

    func loginWithBiometrics() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Log in to FitPick") { success, _ in
                if success, let data = KeychainHelper.standard.read(service: self.service, account: self.savedEmail),
                   let pass = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self.login(email: self.savedEmail, password: pass)
                    }
                } else if !success {
                    print("Biometric authentication failed or was cancelled.")
                }
            }
        }
    }

    func logout() {
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    private func handleSuccessfulAuth(email: String, password: String? = nil) {
        if let password = password, let data = password.data(using: .utf8) {
            KeychainHelper.standard.save(data, service: service, account: email)
        }
        
        self.syncUserToFirestore(email: email)
        
        DispatchQueue.main.async {
            self.savedEmail = email
            self.hasLoggedInBefore = true
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
