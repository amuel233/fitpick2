//
//  Login.swift
//  fitpick2
//
//  Created by Amuel Ryco Nidoy on 1/20/26.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var session: UserSession
    @State var email = ""
    @State private var password = ""
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome Back")
                .font(.largeTitle)
                .bold()

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            // MARK: - Email/Password Login
            Button("Log In") {
                Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    
                    // FIXED: Use the verified user email from Auth result
                    guard let verifiedEmail = authResult?.user.email?.lowercased() else { return }
                    
                    session.email = verifiedEmail
                    syncUserToFirestore(email: verifiedEmail)
                    appState.isLoggedIn = true
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            // MARK: - Google Login
            Button("Log in with Google") {
                handleGoogleSignIn()
            }
        }
        .padding()
    }

    // MARK: - Firestore Sync Logic
    private func syncUserToFirestore(email: String) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(email)

        userRef.getDocument { document, error in
            if let document = document, document.exists {
                print("DEBUG: User document exists for \(email)")
            } else {
                // Initialize a fresh profile if document doesn't exist
                userRef.setData([
                    "email": email,
                    "createdAt": Timestamp(),
                    "username": "",
                    "gender": "Male", // Default gender
                    "selfie": "",
                    "measurements": [
                        "height": 0,
                        "bodyWeight": 0,
                        "chest": 0,
                        "shoulderWidth": 0,
                        "armLength": 0,
                        "waist": 0,
                        "hips": 0,
                        "inseam": 0,
                        "shoeSize": 0
                    ]
                ], merge: true) { error in
                    if let error = error {
                        print("DEBUG: Firestore error: \(error.localizedDescription)")
                    } else {
                        print("DEBUG: Successfully created document for \(email)")
                    }
                }
            }
        }
    }

    private func handleGoogleSignIn() {
        guard let rootViewController = UIApplication.shared
                .connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?
                .windows
                .first?
                .rootViewController else { return }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                print("DEBUG: Google Sign-In error: \(error.localizedDescription)")
                return
            }

            guard let user = result?.user, let email = user.profile?.email.lowercased() else { return }
            
            session.email = email
            syncUserToFirestore(email: email)
            appState.isLoggedIn = true
        }
    }
}
