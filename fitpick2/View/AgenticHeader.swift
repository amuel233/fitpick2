//
//  AgenticHeader.swift
//  fitpick2
//
//  Created by Shakira Mhaire on 1/19/26.
//
import SwiftUI
import GoogleSignIn

/// Top card that displays calendar sync state and next event summary.
struct AgenticHeader: View {
    @EnvironmentObject var session: UserSession
    @StateObject private var vm = AgenticHeaderViewModel()
    @State private var signInError: String? = nil
    @State private var showSignInError: Bool = false
    // The header now shows a dynamic greeting produced by the ViewModel

    var body: some View {
        Group {
            if vm.isConnected {
                VStack(alignment: .leading, spacing: 12) {
                    // Top-level dynamic greeting from the VM
                    if let morning = vm.morningGreeting {
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: "sunrise.fill")
                                .foregroundColor(.orange)
                                .font(.title2)
                            Text(morning)
                                .font(.title2)
                                .bold()
                        }
                    }
                    
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let account = vm.signedInEmail {
                                Text(account)
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.secondary)
                            }
                            if let event = vm.nextEvent {
                                Text(event)
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                            } else {
                                Text("No upcoming events")
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(.secondary)
                            }
                            
                            if let ai = vm.aiSummary {
                                Text(ai)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .fill(Color.primary.opacity(0.06))
                                .frame(width: 64, height: 64)
                            Image(systemName: vm.weatherIconName)
                                .font(.title)
                                .foregroundStyle(.yellow)
                        }
                    }
                    .padding(.vertical, 18)
                    .padding(.horizontal, Theme.cardPadding)
                    .background(.regularMaterial)
                    .cornerRadius(Theme.cornerRadius)
                    .shadow(color: Theme.cardShadow, radius: 10, x: 0, y: 5)
                }
            } else {
                // Show a simple disconnected state; sync action is available in the Sync card below
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundColor(.secondary)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Not connected")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                        Text("Sync your calendar to get event-based suggestions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(Theme.cardPadding)
                .background(.regularMaterial)
                .cornerRadius(Theme.cornerRadius)
                .shadow(color: Theme.cardShadow, radius: 6, x: 0, y: 3)
            }
        } // Ends Group
        .frame(minHeight: 140)
        .onAppear { vm.fetchStatus() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SyncCalendarRequested"))) { _ in
            vm.connectGoogleCalendar { result in
                switch result {
                case .success(let info):
                    if let email = info.email {
                        session.email = email
                        UserDefaults.standard.set(true, forKey: "isSignedIn")
                        UserDefaults.standard.set(email, forKey: "signedInEmail")
                        vm.signedInEmail = email
                    }
                case .failure(let err):
                    signInError = err.localizedDescription
                    showSignInError = true
                }
            }
        }
        .alert("Sign-in Error", isPresented: $showSignInError, actions: {
            Button("OK", role: .cancel) { showSignInError = false }
        }, message: { Text(signInError ?? "An unknown error occurred.") })
    } 
} 

final class AgenticHeaderViewModel: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var nextEvent: String? = nil
    @Published var weatherIconName: String = "cloud.sun"
    @Published var aiSummary: String? = nil
    @Published var signedInEmail: String? = nil
    @Published var morningGreeting: String? = nil
    
    private let calendar = CalendarManager()
    
    func fetchStatus() {
        updateGreeting()
    }
    
    private func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String
        switch hour {
        case 0..<12: greeting = "Good morning"
        case 12..<18: greeting = "Good afternoon"
        default: greeting = "Good evening"
        }
        
        let suggestion = aiSummary ?? "Have a great day."
        DispatchQueue.main.async { [weak self] in
            self?.morningGreeting = "\(greeting)! \(suggestion)"
        }
    }
    
    struct SignInInfo {
        let email: String?
    }
    
    func connectGoogleCalendar(completion: @escaping (Result<SignInInfo, Error>) -> Void) {
        guard let rootViewController = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?
            .windows
            .first?
            .rootViewController else {
            performStubbedConnect(completion: completion)
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController, hint: nil, additionalScopes: ["https://www.googleapis.com/auth/calendar.readonly"]) { [weak self] signInResult, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            DispatchQueue.main.async { self?.isConnected = true }
            
            let email = signInResult?.user.profile?.email
            self?.calendar.fetchNextEvent { event in
                DispatchQueue.main.async {
                    self?.nextEvent = event
                    self?.weatherIconName = "cloud.sun"
                    if let event = event {
                        self?.aiSummary = "It's 18°C tonight. I've picked a layering combo for your \(event)."
                    } else {
                        self?.aiSummary = "It's 18°C tonight."
                    }
                    self?.updateGreeting()
                    completion(.success(SignInInfo(email: email)))
                }
            }
        }
    }
    
    private func performStubbedConnect(completion: @escaping (Result<SignInInfo, Error>) -> Void) {
        isConnected = true
        calendar.fetchNextEvent { [weak self] event in
            DispatchQueue.main.async {
                self?.nextEvent = event
                self?.aiSummary = event != nil ? "It's 18°C tonight. I've picked a layering combo for your \(event!)." : "It's 18°C tonight."
                self?.updateGreeting()
                completion(.success(SignInInfo(email: nil)))
            }
        }
    }
}
/*
 struct AgenticHeader_Previews: PreviewProvider {
 static var previews: some View {
 AgenticHeader()
 .padding()
 }
 }
 
 */
