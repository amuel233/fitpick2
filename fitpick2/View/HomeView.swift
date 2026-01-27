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

    // Responsive 2-column grid for true bento layout
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: Theme.cardSpacing) {
                    
                    // MARK: - Row 1
                    // MOVED TO TOP: Time-based greeting card spans full width
                    TimeGreetingCard(greeting: viewModel.timeBasedGreeting, message: viewModel.morningBriefing)
                        .gridCellColumns(2) // This '2' matches your 'columns' array count to span full width

                    // MARK: - Row 2
                    // MOVED DOWN: Sync Calendar card spans full width/*
                    /*SyncCalendarCard(syncAction: {
                        NotificationCenter.default.post(name: Notification.Name("SyncCalendarRequested"), object: nil)
                    }, tryOnAction: { showCloset = true })
                        .gridCellColumns(2)
                        */

                    // MARK: - Row 3
                    // Agentic Header spans full width
                    AgenticHeader()
                        .gridCellColumns(2)

                    // MARK: - Row 4
                    // Gap Detection card (if available) spans full width
                    if let gap = viewModel.gapDetectionMessage {
                        GapDetectionCard(gap: gap)
                            .gridCellColumns(2)
                    }

                    // MARK: - Row 5
                    // Hero suggestion spans full width
                    HeroSuggestionCard(outfitImage: viewModel.heroImageURL)
                    .gridCellColumns(2)

                    // MARK: - Row 6
                    // Split row: Wardrobe Stats + Weather Tip (1 column each)
                    CombinedWardrobeCard(score: viewModel.sustainabilityScore)
                        .gridCellColumns(1)

                    WeatherAccessoryTip()
                        .gridCellColumns(1)

                    // MARK: - Row 7
                    // Trending news spans full width
                    TrendingFashionNews()
                        .gridCellColumns(2)
                }
                .padding(Theme.cardSpacing + 4)
            }
            .navigationTitle(viewModel.navigationTitle)
            .background(viewModel.backgroundColor.edgesIgnoringSafeArea(.all))
            
            NavigationLink(destination: ClosetView(), isActive: $showCloset) {
                EmptyView()
            }
        }
    }
}

// MARK: - Card Components
struct TimeGreetingCard: View {
    let greeting: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(greeting)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 140)
        .padding(Theme.cardPadding)
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

struct SyncCalendarCard: View {
    let syncAction: () -> Void
    let tryOnAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.plus")
                    .font(.title2)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Sync Your Calendar")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    Text("Sync your calendar to get suggestions for events")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Button(action: syncAction) {
                    Text("Sync")
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: 100)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Spacer()

                Button(action: tryOnAction) {
                    Text("Try-On")
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: 100)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.cardPadding)
        .background(.regularMaterial)
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 2)
    }
}

struct CombinedWardrobeCard: View {
    let score: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Sustainability section
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "leaf.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    Text("Sustainability")
                        .font(.headline.weight(.semibold))
                }
                Text(score)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Divider()
            
            // Wardrobe Pulse section
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "chart.pie.fill")
                        .font(.title2)
                        .foregroundColor(.purple)
                    Text("Wardrobe Pulse")
                        .font(.headline.weight(.semibold))
                }
                Text("Your wardrobe is 72% utilized this week.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .frame(minHeight: 180)
        .padding(Theme.cardPadding)
        .background(.regularMaterial)
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 2)
    }
}

struct SustainabilityCard: View {
    let score: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                Text("Sustainability")
                    .font(.headline.weight(.semibold))
            }
            Text(score)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(minHeight: 140)
        .padding(Theme.cardPadding)
        .background(.regularMaterial)
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 2)
    }
}

struct MorningBriefingCard: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "sunrise.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("Morning Briefing")
                    .font(.headline.weight(.semibold))
            }
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(minHeight: 140)
        .padding(Theme.cardPadding)
        .background(.regularMaterial)
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 2)
    }
}

struct GapDetectionCard: View {
    let gap: HomeViewModel.GapMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Style Gap Detected")
                        .font(.headline.weight(.semibold))
                    Text(gap.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Text(gap.detail)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack {
                Spacer()
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
                .tint(.blue)
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

    struct GapMessage {
        let title: String
        let detail: String
        let externalURL: String
    }

    
    
    private let firestore: FirestoreManager
    private let calendar: CalendarManager
    
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
        
        // Load dynamic data
        loadDynamicContent()
    }
    
    private func loadDynamicContent() {
        // Fetch hero image override from Firestore
        firestore.fetchHeroImageName { [weak self] name in
            if let name = name {
                DispatchQueue.main.async { self?.heroImageURL = name }
            }
        }
        
        // Fetch calendar event and wardrobe counts and compute gap detection
        calendar.fetchNextEvent { [weak self] event in
            guard let self = self, let event = event else { return }
            
            self.firestore.fetchWardrobeCounts { counts in
                // Detect "Formal" keyword in event summary
                let isFormalEvent = event.localizedCaseInsensitiveContains("formal")
                
                // Count likely formal shoes (Heels, Formal etc.)
                let formalShoesCount = counts["Heels", default: 0] + counts["Formal", default: 0]
                
                if isFormalEvent && formalShoesCount == 0 {
                    DispatchQueue.main.async {
                        self.gapDetectionMessage = GapMessage(
                            title: "Style Gap: No formal shoes found for upcoming event",
                            detail: "We couldn't find formal shoes in your closet metadata. View AI-matched picks.",
                            externalURL: "https://www.example-store.com/formal-shoes"
                        )
                    }
                }
            }
        }
    }
    
    static func computeTimeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 0..<12:
            return "Good Morning"
        case 12..<17:
            return "Good Afternoon"
        case 17..<21:
            return "Good Evening"
        default:
            return "Good Night"
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
