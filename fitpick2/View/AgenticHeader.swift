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
    let gap: HomeViewModel.GapMessage?
    let isGeneratingAIPicks: Bool
    let tryOnAction: (() -> Void)?
    @State private var signInError: String? = nil
    @State private var showSignInError: Bool = false

    var body: some View {
        Group {
            if vm.isConnected {
                VStack(spacing: 8) {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            if vm.upcomingEvents.count > 1 {
                                VStack(alignment: .leading, spacing: 4) {
                                    Picker(selection: $vm.selectedEventIndex, label:
                                        Text(vm.upcomingEvents.indices.contains(vm.selectedEventIndex) ? vm.upcomingEvents[vm.selectedEventIndex] : "Upcoming event")
                                            .font(.title3.weight(.bold))
                                            .lineLimit(1)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                            .background(Color.luxeGoldGradient) // UI Update: Luxe Theme
                                            .foregroundColor(.black)
                                            .cornerRadius(10)
                                    ) {
                                        ForEach(vm.upcomingEvents.indices, id: \.self) { idx in
                                            Text(vm.upcomingEvents[idx])
                                                .font(.body.weight(.bold))
                                                .tag(idx)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 2)

                                    if vm.upcomingEventDates.indices.contains(vm.selectedEventIndex), let date = vm.upcomingEventDates[vm.selectedEventIndex] {
                                        Text(vm.formatDateTime(date))
                                            .font(.subheadline)
                                            .foregroundColor(.luxeBeige.opacity(0.6)) // UI Update: Luxe Theme
                                    }
                                }
                            } else if let event = vm.upcomingEvents.first ?? vm.nextEvent {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Upcoming event: \(event)")
                                        .font(.headline.weight(.semibold))
                                        .foregroundColor(.luxeBeige) // UI Update: Luxe Theme
                                    if let date = vm.nextEventDate {
                                        Text(vm.formatDateTime(date))
                                            .font(.subheadline)
                                            .foregroundColor(.luxeBeige.opacity(0.6)) // UI Update: Luxe Theme
                                    }
                                }
                            } else {
                                Text("No upcoming events")
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(.luxeBeige.opacity(0.6))
                            }

                            if vm.upcomingEvents.count > 0 {
                                Text("\(vm.upcomingEvents.count) upcoming event\(vm.upcomingEvents.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundColor(.luxeBeige.opacity(0.5))
                            }

                            if let ai = vm.aiSummary {
                                Text(ai)
                                    .font(.subheadline)
                                    .foregroundColor(.luxeBeige.opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Spacer()

                        if vm.nextEvent == nil {
                            Image(systemName: vm.weatherIconName)
                                .font(.title2)
                                .foregroundColor(.luxeFlax) // UI Update: Luxe Theme
                        }

                        Menu {
                            Button("Google Calendar") { vm.setPreferredProvider("google") }
                            Button("iOS Calendar") { vm.setPreferredProvider("local") }
                            if vm.preferredProvider != nil {
                                Button("Disconnect", role: .destructive) { vm.disconnect() }
                            }
                        } label: {
                            Text(vm.preferredProvider != nil ? "Synced: \(vm.preferredProvider!.capitalized)" : "Sync Calendar")
                                .font(.subheadline.weight(.semibold))
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(vm.preferredProvider != nil ? Color.luxeBeige.opacity(0.1) : Color.luxeFlax) // UI Update: Luxe Theme
                                .foregroundColor(vm.preferredProvider != nil ? .luxeBeige : .black)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 18)
                    .padding(.horizontal, Theme.cardPadding)
                    .background(Color.luxeRichCharcoal.opacity(0.8)) // UI Update: Luxe Theme
                    .cornerRadius(Theme.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .stroke(Color.luxeEcru.opacity(0.3), lineWidth: 1)
                    )

                    if let gap = gap,
                       vm.nextEvent != nil,
                       (vm.preferredProvider != nil || UserDefaults.standard.bool(forKey: "isLocalCalendarSynced")) {
                        GapDetectionCard(gap: gap, isLoading: isGeneratingAIPicks, tryOnAction: tryOnAction)
                            .padding(.top, 8)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundColor(.luxeFlax)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Not connected")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.luxeBeige)
                        Text("Sync your calendar to get event-based suggestions")
                            .font(.caption)
                            .foregroundColor(.luxeBeige.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Menu {
                        Button("Google Calendar") { vm.setPreferredProvider("google") }
                        Button("iOS Calendar") { vm.setPreferredProvider("local") }
                    } label: {
                        Text("Sync Calendar")
                            .font(.subheadline.weight(.semibold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.luxeGoldGradient)
                            .foregroundColor(.black)
                            .cornerRadius(8)
                    }
                }
                .padding(Theme.cardPadding)
                .background(Color.luxeRichCharcoal.opacity(0.8))
                .cornerRadius(Theme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .stroke(Color.luxeEcru.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .frame(minHeight: 140)
        .onChange(of: vm.selectedEventIndex) { newIndex in
            guard vm.upcomingEvents.indices.contains(newIndex) else { return }
            let event = vm.upcomingEvents[newIndex]
            let date = vm.upcomingEventDates.indices.contains(newIndex) ? vm.upcomingEventDates[newIndex] : nil
            vm.nextEvent = event
            vm.nextEventDate = date ?? vm.nextEventDate
            NotificationCenter.default.post(name: Notification.Name("CalendarDidUpdate"), object: nil, userInfo: ["event": event, "eventDate": date as Any])
        }
        .onAppear {
            vm.fetchStatus()
            if UserDefaults.standard.string(forKey: "preferredCalendarProvider") == nil {
                let local = LocalCalendarManager()
                local.fetchAllUpcomingEvents { events in
                    if let first = events.first {
                        let title = first.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? first.notes! : (first.title ?? "Event")
                        DispatchQueue.main.async {
                            vm.upcomingEvents = events.map { ($0.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? $0.notes! : ($0.title ?? "Event")) }
                            vm.upcomingEventDates = events.map { $0.startDate }
                            vm.nextEvent = title
                            vm.nextEventDate = first.startDate
                            if !title.isEmpty {
                                NotificationCenter.default.post(name: Notification.Name("CalendarDidUpdate"), object: nil, userInfo: ["event": title, "eventDate": first.startDate as Any])
                            }
                        }
                    }
                }
            } else {
                if let provider = UserDefaults.standard.string(forKey: "preferredCalendarProvider") {
                    if provider == "google" {
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
                    } else if provider == "local" {
                        vm.connectLocalCalendar { result in
                            switch result {
                            case .success(_):
                                UserDefaults.standard.set(true, forKey: "isLocalCalendarSynced")
                            case .failure(let err):
                                signInError = err.localizedDescription
                                showSignInError = true
                            }
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SyncCalendarRequested"))) { notif in
            let provider = notif.userInfo?["provider"] as? String ?? "google"
            UserDefaults.standard.set(provider, forKey: "preferredCalendarProvider")
            if provider == "google" {
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
            } else {
                vm.connectLocalCalendar { result in
                    switch result {
                    case .success(_):
                        UserDefaults.standard.set(true, forKey: "isLocalCalendarSynced")
                    case .failure(let err):
                        signInError = err.localizedDescription
                        showSignInError = true
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HomeDidRefresh"))) { _ in
            vm.fetchStatus()
            vm.refreshConnection()
        }
        .alert("Sign-in Error", isPresented: $showSignInError, actions: {
            Button("OK", role: .cancel) { showSignInError = false }
        }, message: { Text(signInError ?? "An unknown error occurred.") })
    }
}

final class AgenticHeaderViewModel: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var nextEvent: String? = nil
    @Published var nextEventDate: Date? = nil
    @Published var weatherIconName: String = "cloud.sun"
    @Published var headerGradientStart: Color = Color.blue.opacity(0.08)
    @Published var headerGradientEnd: Color = Color.purple.opacity(0.08)
    @Published var aiSummary: String? = nil
    @Published var signedInEmail: String? = nil
    @Published var morningGreeting: String? = nil
    @Published var preferredProvider: String? = nil
    @Published var upcomingEvents: [String] = []
    @Published var upcomingEventDates: [Date?] = []
    @Published var selectedEventIndex: Int = 0 {
        didSet {
            if upcomingEvents.indices.contains(selectedEventIndex) {
                let event = upcomingEvents[selectedEventIndex]
                let date = upcomingEventDates.indices.contains(selectedEventIndex) ? upcomingEventDates[selectedEventIndex] : nil
                NotificationCenter.default.post(name: Notification.Name("CalendarDidUpdate"), object: nil, userInfo: ["event": event, "eventDate": date as Any])
            }
        }
    }
    
    private let weather = WeatherManager()
    private let calendar = CalendarManager()
    
    init() {
        preferredProvider = UserDefaults.standard.string(forKey: "preferredCalendarProvider")
    }
    
    func fetchStatus() {
        updateGreeting()
        updateHeaderAppearance()
    }
    
    func refreshEvents() {
        calendar.fetchUpcomingEvents(daysAhead: 0) { [weak self] items in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.aiSummary = nil
                self.updateGreeting()
                self.updateHeaderAppearance()
                self.upcomingEvents = items.map { $0.0 }
                self.upcomingEventDates = items.map { $0.2 }
                if let first = self.upcomingEvents.first {
                    self.nextEvent = first
                    self.nextEventDate = self.upcomingEventDates.first ?? nil
                    NotificationCenter.default.post(name: Notification.Name("CalendarDidUpdate"), object: nil, userInfo: ["event": first, "eventDate": self.nextEventDate as Any])
                }
            }
        }
    }

    func refreshConnection() {
        preferredProvider = UserDefaults.standard.string(forKey: "preferredCalendarProvider")
        if preferredProvider == "google" {
            GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
                DispatchQueue.main.async {
                    if let user = user {
                        self?.isConnected = true
                        self?.signedInEmail = user.profile?.email
                        self?.preferredProvider = "google"
                        self?.refreshEvents()
                    } else {
                        self?.refreshEvents()
                    }
                }
            }
        } else if preferredProvider == "local" {
            connectLocalCalendar { _ in }
        }
    }
    
    private func updateGreeting() {
        let greeting = "Good"
        let suggestion = aiSummary ?? "Have a great day."
        DispatchQueue.main.async { [weak self] in
            self?.morningGreeting = "\(greeting)! \(suggestion)"
        }
    }

    func updateHeaderAppearance() {
        let hour = Calendar.current.component(.hour, from: Date())
        var start = Color.blue.opacity(0.08)
        var end = Color.purple.opacity(0.08)
        var defaultIcon = "cloud.sun.fill"

        switch hour {
        case 6..<12:
            start = Color.yellow.opacity(0.12); end = Color.orange.opacity(0.08); defaultIcon = "sun.max.fill"
        case 12..<18:
            start = Color.blue.opacity(0.08); end = Color.purple.opacity(0.08); defaultIcon = "cloud.sun.fill"
        case 18..<22:
            start = Color.purple.opacity(0.12); end = Color.indigo.opacity(0.16); defaultIcon = "moon.stars.fill"
        default:
            start = Color.black.opacity(0.12); end = Color.gray.opacity(0.12); defaultIcon = "moon.stars.fill"
        }

        weather.requestLocation { [weak self] res in
            switch res {
            case .success((let lat, let lon)):
                self?.weather.fetchForecast(lat: lat, lon: lon, forDate: Date()) { forecastRes in
                    switch forecastRes {
                    case .success(let f):
                        let icon = Self.icon(for: f.condition)
                        DispatchQueue.main.async {
                            self?.weatherIconName = icon
                            self?.headerGradientStart = start
                            self?.headerGradientEnd = end
                        }
                    case .failure(_):
                        DispatchQueue.main.async {
                            self?.weatherIconName = defaultIcon
                            self?.headerGradientStart = start
                            self?.headerGradientEnd = end
                        }
                    }
                }
            case .failure(_):
                DispatchQueue.main.async {
                    self?.weatherIconName = defaultIcon
                    self?.headerGradientStart = start
                    self?.headerGradientEnd = end
                }
            }
        }
    }

    private static func icon(for condition: String) -> String {
        let c = condition.lowercased()
        if c.contains("rain") || c.contains("showers") || c.contains("drizzle") { return "cloud.rain.fill" }
        if c.contains("snow") { return "snow" }
        if c.contains("fog") || c.contains("mist") { return "cloud.fog.fill" }
        if c.contains("clear") { return "sun.max.fill" }
        if c.contains("partly") || c.contains("cloudy") { return "cloud.sun.fill" }
        return "cloud.sun.fill"
    }
    
    struct SignInInfo { let email: String? }
    
    func connectGoogleCalendar(completion: @escaping (Result<SignInInfo, Error>) -> Void) {
        guard let rootViewController = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first?.windows.first?.rootViewController else {
            performStubbedConnect(completion: completion)
            return
        }
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController, hint: nil, additionalScopes: ["https://www.googleapis.com/auth/calendar.readonly"]) { [weak self] signInResult, error in
            if let error = error { completion(.failure(error)); return }
            DispatchQueue.main.async { self?.isConnected = true }
            let email = signInResult?.user.profile?.email
            self?.calendar.fetchUpcomingEvents(daysAhead: 0) { items in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.upcomingEvents = items.map { $0.0 }
                    self.upcomingEventDates = items.map { $0.2 }
                    self.weatherIconName = "cloud.sun"
                    self.aiSummary = nil
                    self.updateGreeting()
                    if let first = self.upcomingEvents.first {
                        self.nextEvent = first
                        self.nextEventDate = self.upcomingEventDates.first ?? nil
                        NotificationCenter.default.post(name: Notification.Name("CalendarDidUpdate"), object: nil, userInfo: ["event": first, "eventDate": self.nextEventDate as Any])
                    }
                    completion(.success(SignInInfo(email: email)))
                }
            }
        }
    }

    func connectLocalCalendar(completion: @escaping (Result<SignInInfo, Error>) -> Void) {
        let local = LocalCalendarManager()
        local.fetchAllUpcomingEvents { [weak self] events in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isConnected = true
                self.upcomingEvents = events.map { ($0.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? $0.notes! : ($0.title ?? "Event")) }
                self.upcomingEventDates = events.map { $0.startDate }
                self.nextEvent = self.upcomingEvents.first
                self.nextEventDate = self.upcomingEventDates.first ?? nil
                self.weatherIconName = "cloud.sun"
                self.aiSummary = nil
                self.updateGreeting()
                if let first = self.nextEvent, !first.isEmpty {
                    NotificationCenter.default.post(name: Notification.Name("CalendarDidUpdate"), object: nil, userInfo: ["event": first, "eventDate": self.nextEventDate as Any])
                }
                completion(.success(SignInInfo(email: nil)))
            }
        }
    }

    func setPreferredProvider(_ provider: String, completion: ((Result<SignInInfo, Error>) -> Void)? = nil) {
        UserDefaults.standard.set(provider, forKey: "preferredCalendarProvider")
        preferredProvider = provider
        if provider == "google" { connectGoogleCalendar { res in completion?(res) } } else { connectLocalCalendar { res in completion?(res) } }
    }

    func disconnect() {
        isConnected = false
        signedInEmail = nil
        preferredProvider = nil
        UserDefaults.standard.removeObject(forKey: "preferredCalendarProvider")
    }
    
    private func performStubbedConnect(completion: @escaping (Result<SignInInfo, Error>) -> Void) {
        isConnected = true
        calendar.fetchUpcomingEvents(daysAhead: 0) { [weak self] items in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.upcomingEvents = items.map { $0.0 }
                self.upcomingEventDates = items.map { $0.2 }
                self.nextEvent = self.upcomingEvents.first
                self.nextEventDate = self.upcomingEventDates.first ?? nil
                self.aiSummary = nil
                self.updateGreeting()
                if let first = self.nextEvent, !first.isEmpty {
                    NotificationCenter.default.post(name: Notification.Name("CalendarDidUpdate"), object: nil, userInfo: ["event": first, "eventDate": self.nextEventDate as Any])
                }
                completion(.success(SignInInfo(email: nil)))
            }
        }
    }

    func formatDateTime(_ date: Date) -> String {
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
        return df.string(from: date)
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
