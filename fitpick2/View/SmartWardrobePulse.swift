//
//  SmartWardrobePulse.swift
//  fitpick2
//
//  Created by Shakira Mhaire on 1/19/26.
//
import SwiftUI

// SmartWardrobePulse: shows % of items uploaded in the last 7 days that were used in posts.
struct SmartWardrobePulse: View {
    @State private var totalUploaded: Int = 0
    @State private var usedCount: Int = 0
    @State private var loading: Bool = true
    @EnvironmentObject var appState: AppState

    private let firestore = FirestoreManager()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "chart.pie.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
                Text("Wardrobe Pulse")
                    .font(.headline.weight(.semibold))
            }

            if loading {
                Text("Loading...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if totalUploaded == 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No clothes yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button(action: { appState.selectedTab = 2 }) {
                        Text("Start Uploading")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("fitPickGold"))
                }
            } else {
                let pct = Int(round((Double(usedCount) / Double(max(totalUploaded,1))) * 100.0))
                Text("\(pct)% of items uploaded in the last 7 days were used.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ProgressView(value: Double(usedCount), total: Double(max(totalUploaded,1)))
                    .progressViewStyle(LinearProgressViewStyle(tint: Color.purple))
            }

            Spacer()
        }
        .frame(minHeight: 140)
        .padding(Theme.cardPadding)
        .background(.regularMaterial)
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 2)
        .onAppear(perform: loadPulse)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HomeDidRefresh"))) { _ in
            loadPulse()
        }
    }

    private func loadPulse() {
        loading = true
        firestore.fetchWardrobePulse(lastDays: 7) { total, used in
            DispatchQueue.main.async {
                self.totalUploaded = total
                self.usedCount = used
                self.loading = false
            }
        }
    }
}

struct SmartWardrobePulse_Previews: PreviewProvider {
    static var previews: some View { SmartWardrobePulse().preferredColorScheme(.dark).padding() }
}
