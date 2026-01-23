//
//  WeatherAccessoryTip.swift
//  fitpick2
//
//  Created by Shakira Mhaire on 1/19/26.
//
import SwiftUI

// Placeholder WeatherAccessoryTip used by HomeView.
struct WeatherAccessoryTip: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "cloud.rain.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Weather Tip")
                    .font(.headline.weight(.semibold))
            }
            HStack(spacing: 8) {
                Text("Light rain likely — consider a compact umbrella.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .frame(minHeight: 140)
        .padding(Theme.cardPadding)
        .background(.regularMaterial)
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 2)
    }
}

struct WeatherAccessoryTip_Previews: PreviewProvider {
    static var previews: some View { WeatherAccessoryTip().preferredColorScheme(.dark).padding() }
}
