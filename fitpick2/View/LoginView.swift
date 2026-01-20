//
//  Login.swift
//  fitpick2
//
//  Created by Amuel Ryco Nidoy on 1/20/26.
//

import SwiftUI
import CoreData
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn


struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome Back")
                .font(.largeTitle)
                .bold()

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            Button("Log In") {
                Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
                    if let error = error {
                        print("Login error:", error.localizedDescription)
                        return
                    }
                    // Login successful
                    appState.isLoggedIn = true
                    
                    let db = Firestore.firestore()
                            let userEmail = email.lowercased()
                            let userRef = db.collection("users").document(userEmail)

                            userRef.getDocument { document, error in
                                if let error = error {
                                    print("Firestore error:", error.localizedDescription)
                                    return
                                }

                                if let document = document, document.exists {
                                    // ✅ User document already exists
                                    print("User document already exists")
                                } else {
                                    // 🆕 Create new user document
                                    userRef.setData([
                                        "email": userEmail,
                                        "createdAt": Timestamp(),
                                    ]) { error in
                                        if let error = error {
                                            print("Error creating user document:", error.localizedDescription)
                                        } else {
                                            print("User document created")
                                        }
                                    }
                                }
                    }
                    
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Button("Log in with Google") {
                guard let rootViewController = UIApplication.shared
                        .connectedScenes
                        .compactMap({ $0 as? UIWindowScene })
                        .first?
                        .windows
                        .first?
                        .rootViewController else {
                            return
                    }

                    GIDSignIn.sharedInstance.signIn(
                        withPresenting: rootViewController
                    ) { result, error in
                        if let error = error {
                            print(error.localizedDescription)
                            return
                        }

                        guard let user = result?.user else { return }
                        let email = user.profile?.email
                        print("Signed in as:", email ?? "")
                        appState.isLoggedIn = true
                        
                        let db = Firestore.firestore()
                        
                        db.collection("users")
                            .document(email ?? "")
                                        .setData([
                                            "email": email ?? "",
                                            "createdAt": Timestamp()
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
        }
        .padding()
    }
}
