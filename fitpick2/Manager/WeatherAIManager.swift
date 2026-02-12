//
//  WeatherAIManager.swift
//  fitpick2
//
//  Created by GitHub Copot on 2026-01-30.
//

import Foundation
import UIKit
import FirebaseAILogic

/// Small wrapper to request an AI-generated wardrobe/accessory suggestion
/// given location, time of day, and current weather. Falls back to a rule-based suggestion.
class WeatherAIManager {
    private let ai = FirebaseAI.firebaseAI(backend: .googleAI())
    private lazy var model = ai.generativeModel(modelName: "gemini-2.5-flash")

    func generateSuggestion(location: String?, timeOfDay: String, temperatureC: Double?, condition: String?) async -> String {
        let loc = location ?? "your area"
        let tempStr = temperatureC != nil ? String(format: "%.0f°C", temperatureC!) : "an expected temperature"
        let cond = condition ?? "mixed conditions"

        let prompt = "You are a helpful fashion assistant. Given the user's locality (\(loc)), time of day (\(timeOfDay)), current temperature (\(tempStr)), and weather condition (\(cond)), suggest a brief accessory or small outfit adjustment (one sentence) that improves comfort and style. Keep it short and actionable. Example: 'Carry a lightweight umbrella and wear water-resistant trainers.'"

        // Try AI first
        do {
            let response = try await model.generateContent(prompt)
            if let txt = response.text?.trimmingCharacters(in: .whitespacesAndNewlines), !txt.isEmpty {
                return txt
            }
        } catch {
            // ignore and fallback
        }

        // Fallback heuristics
        return Self.heuristicSuggestion(location: loc, timeOfDay: timeOfDay, tempC: temperatureC, condition: cond)
    }

    private static func heuristicSuggestion(location: String, timeOfDay: String, tempC: Double?, condition: String) -> String {
        let t = tempC ?? 20.0
        if condition.contains("rain") || condition.contains("showers") || condition.contains("drizzle") {
            return "Carry a compact umbrella and wear water-resistant footwear."
        }
        if t <= 8 {
            return "Layer up with a warm coat and consider a scarf for extra warmth."
        }
        if t <= 16 {
            return "A light jacket or knit works well for this temperature."
        }
        if condition.contains("clear") || condition.contains("partly cloudy") {
            return "Sunglasses and a light hat will complement the look today."
        }
        return "Consider breathable fabrics and a light outer layer for variable weather."
    }
}
