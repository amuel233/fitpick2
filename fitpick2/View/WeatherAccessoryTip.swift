//
//  WeatherAccessoryTip.swift
//  fitpick2
//
//  Created by Shakira Mhaire on 1/19/26.
//
import SwiftUI

struct WeatherAccessoryTip: View {
    @State private var suggestion: String = "Loading tip..."
    @State private var loading: Bool = true
    @State private var iconName: String = "cloud.sun.fill"
    private let weather = WeatherManager()
    private let ai = WeatherAIManager()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Weather Tip")
                    .font(.headline.weight(.semibold))
            }

            if loading {
                Text(suggestion)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(suggestion)
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
        .onAppear(perform: loadTip)
    }

    private func loadTip() {
        loading = true
        weather.requestLocation { res in
            switch res {
            case .success((let lat, let lon)):
                // fetch current temp and locality then ask AI
                var gotTemp: Double? = nil
                var locality: String? = nil
                var condition: String? = nil

                let group = DispatchGroup()

                group.enter()
                weather.fetchTemperature(lat: lat, lon: lon) { tempRes in
                    if case .success(let t) = tempRes { gotTemp = t }
                    group.leave()
                }

                group.enter()
                weather.reverseGeocode(lat: lat, lon: lon) { locRes in
                    if case .success(let loc) = locRes { locality = loc }
                    group.leave()
                }

                // also fetch today's condition via forecast for now
                group.enter()
                weather.fetchForecast(lat: lat, lon: lon, forDate: Date()) { fRes in
                    if case .success(let f) = fRes { condition = f.condition }
                    group.leave()
                }

                // when all done, call AI
                group.notify(queue: .main) {
                    let hour = Calendar.current.component(.hour, from: Date())
                    let timeOfDay: String
                    switch hour {
                    case 6..<12: timeOfDay = "morning"
                    case 12..<17: timeOfDay = "afternoon"
                    case 17..<21: timeOfDay = "evening"
                    default: timeOfDay = "night"
                    }
                    // choose icon based on condition
                    let chosenIcon = Self.icon(for: condition)
                    DispatchQueue.main.async {
                        self.iconName = chosenIcon
                    }

                    Task {
                        let aiSuggestion = await ai.generateSuggestion(location: locality, timeOfDay: timeOfDay, temperatureC: gotTemp, condition: condition)
                        DispatchQueue.main.async {
                            self.suggestion = aiSuggestion
                            self.loading = false
                        }
                    }
                }

            case .failure(_):
                // fallback: simple tip and icon
                DispatchQueue.main.async {
                    self.suggestion = "Check the forecast — layer for changing conditions."
                    self.iconName = "cloud.sun.fill"
                    self.loading = false
                }
            }
        }
    }

    private static func icon(for condition: String?) -> String {
        guard let c = condition?.lowercased() else { return "cloud.sun.fill" }
        if c.contains("rain") || c.contains("showers") || c.contains("drizzle") { return "cloud.rain.fill" }
        if c.contains("snow") { return "snow" }
        if c.contains("fog") || c.contains("mist") { return "cloud.fog.fill" }
        if c.contains("clear") { return "sun.max.fill" }
        if c.contains("partly") || c.contains("cloudy") { return "cloud.sun.fill" }
        return "cloud.sun.fill"
    }
}

struct WeatherAccessoryTip_Previews: PreviewProvider {
    static var previews: some View { WeatherAccessoryTip().preferredColorScheme(.dark).padding() }
}
