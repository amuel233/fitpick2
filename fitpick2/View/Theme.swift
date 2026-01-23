//
//  Theme.swift
//  fitpick2
//
//  Created by Shakira Mhaire on 1/19/26.
//
import SwiftUI

enum Theme {
    // Standard corner radius for cards
    static let cornerRadius: CGFloat = 20

    // Padding applied inside cards
    static let cardPadding: CGFloat = 20

    // Vertical / horizontal spacing between elements
    static let cardSpacing: CGFloat = 28

    // Subtle shadow color used to lift cards off the background in light/dark
    static let cardShadow = Color.black.opacity(0.06)

    // Use system accent to stay consistent with app settings / light mode
    static let accent = Color.accentColor
}
