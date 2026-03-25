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
    
    // Track which field is active for the gold border effect
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        ZStack {
            // Background: Using the defined Luxe Spotlight Gradient
            Color.luxeSpotlightGradient
                .ignoresSafeArea()
            
            // Ambient Glows: Using Luxe palette colors for soft depth
            GeometryReader { geo in
                ZStack {
                    Circle().fill(Color.luxeEcru).frame(width: 400, height: 400)
                        .blur(radius: 150).opacity(0.08).offset(x: -150, y: -200)
                    Circle().fill(Color.luxeFlax).frame(width: 300, height: 300)
                        .blur(radius: 120).opacity(0.05).offset(x: 200, y: 100)
                }
            }
            
            VStack(spacing: 25) {
                // Header section with Logo and Title
                VStack(spacing: 15) {
                    Image("icon-1024")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .cornerRadius(22)
                        // Added shadow using Luxe Flax for a gold-tinted glow
                        .shadow(color: Color.luxeFlax.opacity(0.3), radius: 15, x: 0, y: 8)
                    
                    // Title: Using luxeBeige for the primary brand text
                    Text("FitPick")
                        .font(.system(size: 38, weight: .black))
                        .kerning(4)
                        .foregroundColor(.luxeBeige)
                        .modifier(ShimmerEffect())
                    
                    Text("YOUR AI STYLIST")
                        .font(.system(size: 12, weight: .bold))
                        .kerning(4)
                        .foregroundColor(.luxeFlax) // Secondary brand color
                }
                .padding(.top, 40)

                // Input Fields with Gold Focus Borders
                VStack(spacing: 18) {
                    customTextField(placeholder: "Email", text: $email, field: .email, isSecure: false)
                    customTextField(placeholder: "Password", text: $password, field: .password, isSecure: true)
                }
                .padding(.horizontal, 30)

                // Primary Login Button
                VStack(spacing: 20) {
                    Button(action: {
                        auth.login(email: email, password: password)
                    }) {
                        Text("LOG IN")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .kerning(1.5)
                            .foregroundColor(.luxeBlack) // Dark text on gold button
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.luxeGoldGradient) // Using official Luxe Gold Gradient
                            .cornerRadius(14)
                            .shimmer()
                            .shadow(color: Color.luxeEcru.opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Text("OR")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.luxeBeige.opacity(0.3)) // Subdued beige text

                    // Google Sign-In Button
                    Button(action: {
                        auth.loginWithGoogle()
                    }) {
                        HStack {
                            Image(systemName: "globe")
                            Text("CONTINUE WITH GOOGLE")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .kerning(1)
                        .foregroundColor(.luxeBeige)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.luxeEcru.opacity(0.5), lineWidth: 1) // Gold border
                        )
                    }
                }
                .padding(.horizontal, 30)

                // Face ID Section
                if auth.hasLoggedInBefore {
                    Button(action: {
                        auth.loginWithBiometrics()
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "faceid")
                                .font(.system(size: 40))
                                .shimmer()
                            Text("FACE ID")
                                .font(.system(size: 10, weight: .bold))
                                .kerning(1.5)
                        }
                        .foregroundColor(Color.luxeFlax.opacity(0.8)) // Flax gold accent
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

    // Helper view for Gold-Bordered inputs
    @ViewBuilder
    private func customTextField(placeholder: String, text: Binding<String>, field: Field, isSecure: Bool) -> some View {
        let isFocused = focusedField == field
        
        Group {
            if isSecure {
                SecureField("", text: text, prompt: Text(placeholder).foregroundColor(.luxeFlax.opacity(0.4)))
                    .focused($focusedField, equals: field)
            } else {
                TextField("", text: text, prompt: Text(placeholder).foregroundColor(.luxeFlax.opacity(0.4)))
                    .focused($focusedField, equals: field)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
            }
        }
        .padding()
        // Using Rich Charcoal for input backgrounds to match the spotlight theme
        .background(Color.luxeRichCharcoal.opacity(0.6))
        .cornerRadius(12)
        .foregroundColor(.luxeBeige)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? Color.luxeFlax : Color.luxeEcru.opacity(0.2), lineWidth: isFocused ? 1.5 : 1)
                .shadow(color: isFocused ? Color.luxeFlax.opacity(0.2) : .clear, radius: 4)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Supporting Luxury Components

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = -1.5

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Color.luxeBeige.opacity(0.3), location: 0.5), // Shimmer uses beige
                            .init(color: .clear, location: 1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geometry.size.width * 0.4)
                    .offset(x: phase * geometry.size.width)
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(Animation.linear(duration: 3).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerEffect())
    }
}
