//
//  LoginView.swift
//  fitpick2
//
//  Created by Amuel Ryco Nidoy on 1/20/26.
//

import SwiftUI

struct LoginView: View {
    // Access the global app state and session
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var session: UserSession
    
    // Access the logic controller
    @StateObject private var auth = AuthManager.shared
    
    @State private var email = ""
    @State private var password = ""
    
    // Updated Theme Colors
    let fitPickGold = Color("fitPickGold")
    let fitPickWhite = Color(red: 245/255, green: 245/255, blue: 247/255) // Clean off-white
    let fitPickText = Color(red: 26/255, green: 26/255, blue: 27/255)   // Dark gray/black for text

    var body: some View {
        ZStack {
            // Background changed to White
            fitPickWhite.ignoresSafeArea()
            
            VStack(spacing: 25) {
                // Header section with Logo and Title
                VStack(spacing: 15) {
                    Image("icon-1024")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .cornerRadius(24)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    Text("FitPick")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(fitPickGold) // Text changed to dark
                    
                    Text("Your AI Stylist")
                        .font(.subheadline)
                        .foregroundColor(.secondary) // Adjusted for light theme
                }
                .padding(.top, 40)

                // Input Fields with light theme styling
                VStack(spacing: 15) {
                    TextField("", text: $email, prompt: Text("Email").foregroundColor(.gray))
                        .padding()
                        .background(Color.white) // White background for inputs
                        .cornerRadius(12)
                        .foregroundColor(fitPickText) // Dark text input
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    
                    SecureField("", text: $password, prompt: Text("Password").foregroundColor(.gray))
                        .padding()
                        .background(Color.white) // White background for inputs
                        .cornerRadius(12)
                        .foregroundColor(fitPickText) // Dark text input
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                .padding(.horizontal)

                // Primary Login Button
                Button(action: {
                    auth.login(email: email, password: password)
                }) {
                    Text("Log In")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(fitPickGold)
                        .foregroundColor(.white) // White text on gold for better contrast
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                Text("OR")
                    .font(.caption)
                    .foregroundColor(.gray)

                // Google Sign-In Button with Gold Border
                Button(action: {
                    auth.loginWithGoogle()
                }) {
                    HStack {
                        Image(systemName: "globe")
                        Text("Continue with Google")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundColor(fitPickGold)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(fitPickGold, lineWidth: 1)
                    )
                }
                .padding(.horizontal)

                // Face ID Section
                if auth.hasLoggedInBefore {
                    Button(action: {
                        auth.loginWithBiometrics()
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "faceid")
                                .font(.system(size: 40))
                            Text("Use Face ID")
                                .font(.footnote)
                        }
                        .foregroundColor(fitPickGold)
                    }
                    .padding(.top, 10)
                }
                
                Spacer()
            }
        }
        .alert("Login Failed", isPresented: $auth.showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(auth.errorMessage ?? "An unknown error occurred.")
        }
        .onAppear {
            if auth.hasLoggedInBefore {
                auth.loginWithBiometrics()
            }
        }
    }
}
