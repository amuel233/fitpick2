//
//  Login.swift
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
    
    // Logo Colors derived from your branding
    let fitPickGold = Color("fitPickGold")
    let fitPickBlack = Color("fitPickBlack")

    var body: some View {
        ZStack {
            // Apply the theme background
            Color(red: 26/255, green: 26/255, blue: 27/255).ignoresSafeArea()
            
            VStack(spacing: 25) {
                // Header section with Logo and Title
                VStack(spacing: 15) {
                    Image("icon-1024")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .cornerRadius(24)
                    
                    Text("FitPick")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(fitPickGold)
                    
                    Text("Your AI Stylist")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 40)

                // Input Fields with dark theme styling
                VStack(spacing: 15) {
                    TextField("", text: $email, prompt: Text("Email").foregroundColor(.gray))
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("", text: $password, prompt: Text("Password").foregroundColor(.gray))
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                }
                .padding(.horizontal)

                // Primary Login Button using Brand Gold
                Button(action: {
                    auth.login(email: email, password: password)
                }) {
                    Text("Log In")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(fitPickGold)
                        .foregroundColor(.black)
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(fitPickGold, lineWidth: 1)
                    )
                }
                .padding(.horizontal)

                // Face ID Section - Only visible if user has logged in successfully before
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
        // Centralized Error Alert
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
