//
//  SmartWardrobePulse.swift
//  fitpick2
//
//  Created by Shakira Mhaire on 1/19/26.
//
import SwiftUI

// Placeholder SmartWardrobePulse card used by HomeView.
struct SmartWardrobePulse: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            Spacer()
        }
        .frame(minHeight: 140)
        .padding(Theme.cardPadding)
        .background(.regularMaterial)
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 2)
    }
}

struct SmartWardrobePulse_Previews: PreviewProvider {
    static var previews: some View { SmartWardrobePulse().preferredColorScheme(.dark).padding() }
}
