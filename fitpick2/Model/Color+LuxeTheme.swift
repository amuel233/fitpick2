//
//  Color+LuxeTheme.swift
//  fitpick2
//
//  Created by Bryan Gavino on 2/17/26.
//

import SwiftUI

extension Color {
    // MARK: - Luxe Palette
    static let luxeRichCharcoal = Color(hex: "1C1C1E") // Spotlight center
    static let luxeDeepOnyx = Color(hex: "080808")     // Background edges
    static let luxeBlack = Color(hex: "050505")        // Deepest Black
    static let luxeEcru = Color(hex: "D0AC77")         // Dark Gold / Bronze
    static let luxeFlax = Color(hex: "EBD58D")         // Light Gold
    static let luxeBeige = Color(hex: "FFFEE5")        // Text / Highlights
    
    // MARK: - Gradients
    static var luxeGoldGradient: LinearGradient {
        LinearGradient(colors: [.luxeEcru, .luxeFlax], startPoint: .leading, endPoint: .trailing)
    }
    
    static var luxeSpotlightGradient: RadialGradient {
        RadialGradient(
            gradient: Gradient(colors: [.luxeRichCharcoal, .luxeDeepOnyx, .black]),
            center: .top,
            startRadius: 0,
            endRadius: UIScreen.main.bounds.height * 0.8
        )
    }

    // MARK: - Hex Initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
