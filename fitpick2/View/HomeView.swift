//
//  Login.swift
//  fitpick2
//
//  Created by Amuel Ryco Nidoy on 1/20/26.
//

import SwiftUI
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCloset: Bool = false
    @StateObject private var viewModel = HomeViewModel()

    // Single-column layout so each card spans full width
    private let columns = [
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.cardSpacing) {
                    // Top area: Greeting + Agentic Header occupy full width
                    TimeGreetingCard(greeting: viewModel.timeBasedGreeting, message: viewModel.morningBriefing, temperature: viewModel.temperatureString, location: viewModel.locationString, tryOnAvailable: viewModel.tryOnAvailable, tryOnAction: {
                        appState.selectedTab = viewModel.closetTabIndex
                    })

                    AgenticHeader(gap: viewModel.gapDetectionMessage, tryOnAction: {
                        if let gap = viewModel.gapDetectionMessage, gap.useTryOn {
                            appState.selectedTab = viewModel.closetTabIndex
                        }
                    })

                    // Responsive grid for remaining cards (adaptive columns)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: Theme.cardSpacing)], spacing: Theme.cardSpacing) {

                        HStack(spacing: Theme.cardSpacing) {
                            SmartWardrobePulse()
                                .frame(maxWidth: .infinity)
                            WeatherAccessoryTip()
                                .frame(maxWidth: .infinity)
                        }

                        // Solo Sustainability card removed (CombinedWardrobeCard covers this)

                        // Morning briefing card removed

                        TrendingFashionNews()
                    }
                }
                .padding(Theme.cardSpacing)
            }
            .refreshable {
                viewModel.refreshAll()
            }
            .navigationTitle(viewModel.navigationTitle)
            .background(viewModel.backgroundColor.edgesIgnoringSafeArea(.all))
            
            NavigationLink(destination: ClosetView(), isActive: $showCloset) {
                EmptyView()
            }
        }
    }
}

extension TimeGreetingCard {
    static func gradientForCurrentTime() -> [Color] {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12:
            return [Color.yellow.opacity(0.12), Color.orange.opacity(0.08)]
        case 12..<18:
            return [Color.blue.opacity(0.08), Color.purple.opacity(0.08)]
        case 18..<22:
            return [Color.purple.opacity(0.12), Color.indigo.opacity(0.16)]
        default:
            return [Color.black.opacity(0.12), Color.gray.opacity(0.12)]
        }
    }

    static func iconNameForCurrentTime() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return "sun.max.fill"
        case 12..<18: return "cloud.sun.fill"
        case 18..<22: return "moon.stars.fill"
        default: return "moon.stars.fill"
        }
    }

    static func iconColorForCurrentTime() -> Color {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return Color.yellow
        case 12..<18: return Color.yellow
        case 18..<22: return Color.white
        default: return Color.white
        }
    }
}

// MARK: - Card Components
struct TimeGreetingCard: View {
    let greeting: String
    let message: String
    let temperature: String?
    let location: String?
    let tryOnAvailable: Bool
    let tryOnAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: Self.iconNameForCurrentTime())
                    .font(.title2)
                    .foregroundStyle(Self.iconColorForCurrentTime())
                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting)
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let temp = temperature {
                        HStack(spacing: 8) {
                            Text(temp)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.secondary)
                            if let loc = location {
                                Text("· \(loc)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                Spacer()
            }

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if tryOnAvailable {
                HStack {
                    Spacer()
                    Button(action: { tryOnAction?() }) {
                        Text("Try On")
                            .font(.subheadline.weight(.semibold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("fitPickGold"))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 140)
        .padding(Theme.cardPadding)
        .background(
            LinearGradient(gradient: Gradient(colors: Self.gradientForCurrentTime()), startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 2)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.08),
                    Color.purple.opacity(0.08)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 2)
    }
}



// Sustainability/combined card removed; SmartWardrobePulse provides current pulse and upload CTA.

struct GapDetectionCard: View {
    let gap: HomeViewModel.GapMessage
    let tryOnAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Style Gap Detected")
                        .font(.headline.weight(.semibold))
                    if gap.useTryOn {
                        Text(gap.title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("(No suitable clothes for event)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }

            Text(gap.detail)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                if gap.useTryOn {
                    Button(action: { tryOnAction?() }) {
                        Text("Try On")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("fitPickGold"))
                } else {
                    Button(action: {
                        if let url = URL(string: gap.externalURL) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("View Picks")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentColor)
                }
            }
        }
        .padding(Theme.cardPadding)
        .background(.regularMaterial)
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 2)
    }
}


final class HomeViewModel: ObservableObject {
    // External tab index for Closet
    let closetTabIndex: Int

    // UI configuration
    let cornerRadius: CGFloat
    let backgroundColor: Color

    @Published var heroImageURL: String?
    @Published var sustainabilityScore: String
    @Published var morningBriefing: String
    @Published var navigationTitle: String
    @Published var gapDetectionMessage: GapMessage?
    @Published var timeBasedGreeting: String
    @Published var locationString: String? = nil
    @Published var temperatureString: String? = nil

    struct GapMessage {
        let title: String
        let detail: String
        let externalURL: String
        let useTryOn: Bool
    }
    private var lastCoordinates: (Double, Double)? = nil


    
    
    private let firestore: FirestoreManager
    private let calendar: CalendarManager
    private let weather = WeatherManager()
    private var calendarObserver: NSObjectProtocol?
    
        init(closetTabIndex: Int = 1,
            cornerRadius: CGFloat = Theme.cornerRadius,
            backgroundColor: Color = Color(.systemBackground),
            heroImageURL: String? = nil,
            sustainabilityScore: String = "Cost Per Wear: $5.00",
            morningBriefing: String = "Breezy commute—I suggest the windbreaker.",
            navigationTitle: String = "Today",
            firestore: FirestoreManager = FirestoreManager(),
            calendar: CalendarManager = CalendarManager()) {
        
        self.closetTabIndex = closetTabIndex
        self.cornerRadius = cornerRadius
        self.backgroundColor = backgroundColor
        self.heroImageURL = heroImageURL
        self.sustainabilityScore = sustainabilityScore
        self.morningBriefing = morningBriefing
        self.navigationTitle = navigationTitle
        self.firestore = firestore
        self.calendar = calendar
        self.timeBasedGreeting = Self.computeTimeBasedGreeting()
        self.morningBriefing = Self.computeTimeBasedBriefing()
        
        // Load dynamic data
        loadDynamicContent()

        // Fetch location-based temperature
        weather.requestLocation { [weak self] res in
            switch res {
            case .success((let lat, let lon)):
                self?.lastCoordinates = (lat, lon)
                self?.weather.fetchTemperature(lat: lat, lon: lon) { tempRes in
                    switch tempRes {
                    case .success(let temp):
                        DispatchQueue.main.async {
                            self?.temperatureString = String(format: "%.0f°C", temp)
                        }
                    case .failure(_): break
                    }
                }

                self?.weather.reverseGeocode(lat: lat, lon: lon) { locRes in
                    switch locRes {
                    case .success(let locality):
                        DispatchQueue.main.async {
                            self?.locationString = locality
                        }
                    case .failure(_): break
                    }
                }

            case .failure(_): break
            }
        }

        // Listen for calendar updates (from AgenticHeader) — only re-evaluate Try-On suggestions when an event arrives
            // Listen for calendar updates (from AgenticHeader) — handle combined style gap + weather + try-on
            calendarObserver = NotificationCenter.default.addObserver(forName: Notification.Name("CalendarDidUpdate"), object: nil, queue: .main) { [weak self] note in
                guard let self = self else { return }
                let event = note.userInfo?["event"] as? String
                let eventDate = note.userInfo?["eventDate"] as? Date
                if let event = event, !event.isEmpty {
                    self.handleCalendarEvent(event: event, date: eventDate)
                }
            }
    }

    @Published var tryOnAvailable: Bool = false

    // Handle a calendar event: compute weather for date, check wardrobe, and set gapDetectionMessage accordingly
    func handleCalendarEvent(event: String, date: Date?) {
        // Heuristic mapping from event keywords to required subcategories
        let lower = event.lowercased()
        var required: [String] = ["Top"]
        if lower.contains("formal") || lower.contains("gala") || lower.contains("black tie") {
            required = ["Formal", "Heels"]
        } else if lower.contains("meeting") || lower.contains("interview") || lower.contains("presentation") {
            required = ["Blazer", "Shirt"]
        } else if lower.contains("workout") || lower.contains("run") || lower.contains("yoga") {
            required = ["Activewear"]
        } else if lower.contains("beach") || lower.contains("pool") {
            required = ["Swim"]
        }

        // Fetch wardrobe counts
        firestore.fetchWardrobeCounts { [weak self] counts in
            guard let self = self else { return }
            let availableCount = required.reduce(0) { $0 + (counts[$1] ?? 0) }
            let hasItems = availableCount > 0

            // Prepare weather snippet if we have coordinates and a date
            var weatherSnippet: String? = nil
            if let coords = self.lastCoordinates, let d = date {
                self.weather.fetchForecast(lat: coords.0, lon: coords.1, forDate: d) { res in
                    switch res {
                    case .success(let forecast):
                        let temper = Int(round((forecast.max + forecast.min) / 2.0))
                        weatherSnippet = "Expect \(temper)°C, \(forecast.condition)"
                    case .failure(_):
                        weatherSnippet = nil
                    }

                    DispatchQueue.main.async {
                        self.updateGapMessage(event: event, required: required, hasItems: hasItems, weatherSnippet: weatherSnippet)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.updateGapMessage(event: event, required: required, hasItems: hasItems, weatherSnippet: weatherSnippet)
                }
            }
        }
    }

    private func updateGapMessage(event: String, required: [String], hasItems: Bool, weatherSnippet: String?) {
        let title: String
        if hasItems {
            title = "Suggested Outfit Available"
        } else {
            title = "Style Gap Detected"
        }

        let outfit = required.joined(separator: ", ")
        var detail = "Suggested: \(outfit) for \(event)."
        if let w = weatherSnippet {
            detail += " \(w)."
        }

        if hasItems {
            self.tryOnAvailable = true
            self.gapDetectionMessage = GapMessage(title: title, detail: detail, externalURL: "", useTryOn: true)
        } else {
            self.tryOnAvailable = false
            // build google search URL including all required items and location
            let items = required.joined(separator: " ")
            let loc = self.locationString ?? ""
            let rawQuery = loc.isEmpty ? "buy \(items)" : "buy \(items) in \(loc)"
            let query = rawQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "buy+\(items)"
            let url = "https://www.google.com/search?q=\(query)"
            self.gapDetectionMessage = GapMessage(title: title, detail: detail, externalURL: url, useTryOn: false)
        }
    }

    /// Build a Google search URL for the provided items and optional event description, using the detected `locationString` when available.
    private func buildGoogleSearchURL(for items: [String], event: String? = nil) -> String {
        let itemsPart = items.joined(separator: " ")
        var rawQuery = "buy \(itemsPart)"
        if let e = event, !e.isEmpty {
            rawQuery += " for \(e)"
        }
        if let loc = self.locationString, !loc.isEmpty {
            rawQuery += " in \(loc)"
        }
        let query = rawQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? itemsPart.replacingOccurrences(of: " ", with: "+")
        return "https://www.google.com/search?q=\(query)"
    }

    /// Decide whether a try-on suggestion should be offered for the given event
    func evaluateTryOn(for event: String?) {
        let upcoming = event ?? ""
        firestore.fetchWardrobeCounts { [weak self] counts in
            guard let self = self else { return }

            // Simple heuristic: if event looks formal, require formal shoes; otherwise require at least one item
            let isFormal = upcoming.localizedCaseInsensitiveContains("formal") || upcoming.localizedCaseInsensitiveContains("black tie") || upcoming.localizedCaseInsensitiveContains("gala")
            let formalCount = (counts["Heels"] ?? 0) + (counts["Formal"] ?? 0)
            let totalItems = counts.values.reduce(0, +)

            DispatchQueue.main.async {
                if isFormal {
                    self.tryOnAvailable = formalCount > 0
                        if !self.tryOnAvailable {
                        let url = self.buildGoogleSearchURL(for: ["Formal","Heels"], event: upcoming)
                        self.gapDetectionMessage = GapMessage(
                            title: "Style Gap: No formal shoes found",
                            detail: "We couldn't find formal shoes in your closet metadata. View suggested picks.",
                            externalURL: url,
                            useTryOn: false
                        )
                    } else {
                        self.gapDetectionMessage = nil
                    }
                } else {
                    self.tryOnAvailable = totalItems > 0
                    if !self.tryOnAvailable {
                        let url = self.buildGoogleSearchURL(for: ["clothing"], event: upcoming)
                        self.gapDetectionMessage = GapMessage(
                            title: "Style Gap: Empty wardrobe",
                            detail: "We couldn't find suitable items in your closet.",
                            externalURL: url,
                            useTryOn: false
                        )
                    } else {
                        self.gapDetectionMessage = nil
                    }
                }
            }
        }
    }

    deinit {
        if let obs = calendarObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }
    
    private func loadDynamicContent() {
        // Fetch hero image override from Firestore
        firestore.fetchHeroImageName { [weak self] name in
            if let name = name {
                DispatchQueue.main.async { self?.heroImageURL = name }
            }
        }
        
        // Fetch calendar event details and compute gap detection (keeps 'Suggested' state)
        calendar.fetchNextEventDetail { [weak self] event, date in
            guard let self = self, let event = event else { return }
            // Reuse the same calendar-event handling pipeline so suggested outfits persist after refresh
            DispatchQueue.main.async {
                self.handleCalendarEvent(event: event, date: date)
            }
        }
    }

    /// Public refresh entry used by pull-to-refresh in the UI
    func refreshAll() {
        // Reload hero, calendar, and wardrobe state
        loadDynamicContent()

        // Refresh temperature and location
        weather.requestLocation { [weak self] res in
            guard let self = self else { return }
            switch res {
            case .success((let lat, let lon)):
                self.lastCoordinates = (lat, lon)
                self.weather.fetchTemperature(lat: lat, lon: lon) { tempRes in
                    switch tempRes {
                    case .success(let temp):
                        DispatchQueue.main.async { self.temperatureString = String(format: "%.0f°C", temp) }
                    case .failure(_): break
                    }
                }

                self.weather.reverseGeocode(lat: lat, lon: lon) { locRes in
                    switch locRes {
                    case .success(let locality):
                        DispatchQueue.main.async { self.locationString = locality }
                    case .failure(_): break
                    }
                }
            case .failure(_): break
            }
        }
        // Notify other components to refresh (e.g., trending news)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("HomeDidRefresh"), object: nil)
        }
    }
    
    static func computeTimeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<18:
            return "Good afternoon"
        case 18..<22:
            return "Good evening"
        default:
            return "Good night"
        }
    }

    static func computeTimeBasedBriefing() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<9:
            return "Light layers are recommended for cooler mornings."
        case 9..<12:
            return "A casual smart look works well for mixed plans."
        case 12..<18:
            return "Consider breathable fabrics for daytime comfort."
        case 18..<22:
            return "Dress up for night events or relax with comfortable layers."
        default:
            return "Keep it cozy and comfortable for winding down."
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HomeView()
                .environmentObject(AppState())
            HomeView()
                .environmentObject(AppState())
                .previewDisplayName("Light")
        }
    }
}
