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
                    .foregroundColor(.luxeFlax)
                Text("Wardrobe Pulse")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.luxeBeige)
            }

            if loading {
                ProgressView().tint(.luxeFlax)
            } else if totalUploaded == 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No clothes yet")
                        .font(.subheadline)
                        .foregroundColor(.luxeBeige.opacity(0.7))

                    Button(action: { appState.selectedTab = 2 }) {
                        Text("Start Uploading")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.luxeBlack)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.luxeGoldGradient)
                            .cornerRadius(10)
                    }
                }
            } else {
                let pct = Int(round((Double(usedCount) / Double(max(totalUploaded,1))) * 100.0))
                Text("\(pct)% of items used this week.")
                    .font(.subheadline)
                    .foregroundColor(.luxeBeige.opacity(0.8))

                ProgressView(value: Double(usedCount), total: Double(max(totalUploaded,1)))
                    .progressViewStyle(LinearProgressViewStyle(tint: Color.luxeFlax))
                    .background(Color.luxeBeige.opacity(0.1))
                    .cornerRadius(4)
            }
            Spacer()
        }
        .frame(minHeight: 140)
        .padding(Theme.cardPadding)
        .background(Color.luxeRichCharcoal.opacity(0.8))
        .cornerRadius(Theme.cornerRadius)
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Color.luxeEcru.opacity(0.2), lineWidth: 1))
        .onAppear(perform: loadPulse)
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
