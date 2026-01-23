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
    @EnvironmentObject var session: UserSession // Add this line
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
                    
                    let db = Firestore.firestore()
                            let userEmail = email.lowercased()
                            let userRef = db.collection("users").document(userEmail)

                            userRef.getDocument { document, error in
                                if let error = error {
                                    print("Firestore error:", error.localizedDescription)
                                    return
                                }

                                if let document = document, document.exists {
                                    // User document already exists
                                    print("User document already exists")
                                } else {
                                    // Create new user document
                                    userRef.setData([
                                        "email": userEmail,
                                        "createdAt": Timestamp()
                                    ]) { error in
                                        if let error = error {
                                            print("Error creating user document:", error.localizedDescription)
                                        } else {
                                            print("User document created")
                                        }
                                    }
                                }
                    }
                    
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

                        guard let user = result?.user else { return }
                        let email = user.profile?.email
                        session.email = email
                        print("Signed in as:", email ?? "")
                        appState.isLoggedIn = true
                        
                        let db = Firestore.firestore()
                        
                        db.collection("users")
                            .document(email ?? "")
                                        .setData([
                                            "email": email ?? "",
                                            "createdAt": Timestamp(),
                                            "username": "",
                                            "gender": "",
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
                                                print("Firestore error:", error)
                                            } else {
                                                print("User document created")
                                                appState.isLoggedIn = true
                                            }
                                        }
                    }
            }

            guard let user = result?.user, let email = user.profile?.email.lowercased() else { return }
            
            session.email = email
            syncUserToFirestore(email: email)
            appState.isLoggedIn = true
        }
    }
}
