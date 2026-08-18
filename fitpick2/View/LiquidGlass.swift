//
//  LiquidGlass.swift
//  fitpick2
//
//  Created for Liquid Glass UI Design System (Optimized for 60/120 FPS Performance)
//

import SwiftUI

// MARK: - Liquid Glass Card Modifier
struct LiquidGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = Theme.cornerRadius
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    
    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    if reduceTransparency {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.luxeRichCharcoal)
                    } else {
                        ZStack {
                            // Base 1: Hardware-Accelerated Frosted Blur Material
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(.ultraThinMaterial)
                            
                            // Base 2: Deep Tint for high contrast & legibility
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.luxeRichCharcoal.opacity(0.55),
                                            Color.luxeDeepOnyx.opacity(0.75)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            // Base 3: Specular Top Highlight (Glass Sheen)
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .white.opacity(0.16), location: 0.0),
                                            .init(color: .white.opacity(0.03), location: 0.22),
                                            .init(color: .clear, location: 0.50)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                // Specular Refraction Glass Border
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.60), location: 0.0),
                                .init(color: Color.luxeFlax.opacity(0.40), location: 0.25),
                                .init(color: .white.opacity(0.08), location: 0.60),
                                .init(color: Color.luxeEcru.opacity(0.30), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Liquid Glass Pill & Secondary Button Modifier
struct LiquidGlassPillModifier: ViewModifier {
    var cornerRadius: CGFloat = 10
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.45), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Liquid Glass Gold Button Style Modifier
struct LiquidGlassGoldButtonModifier: ViewModifier {
    var cornerRadius: CGFloat = 10
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Luxe Gold Base
                    Color.luxeGoldGradient
                    
                    // Glass Sheen on Top of Gold
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.35), location: 0.0),
                            .init(color: .white.opacity(0.05), location: 0.4),
                            .init(color: .clear, location: 0.7)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.65), Color.luxeFlax.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.luxeFlax.opacity(0.25), radius: 8, x: 0, y: 3)
    }
}

// MARK: - High-Performance Liquid Ambient Background (Metal GPU Rendered)
struct LiquidGlassBackgroundView: View {
    var body: some View {
        ZStack {
            // Deep base
            Color.luxeBlack.ignoresSafeArea()
            
            // Spotlight base gradient
            Color.luxeSpotlightGradient.ignoresSafeArea()
            
            // Hardware-Accelerated Ambient Light Orbs (Zero blur passes, rendered as pure GPU radial shaders)
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height
                
                // Top-right glowing liquid orb (Flax Gold)
                RadialGradient(
                    stops: [
                        .init(color: Color.luxeFlax.opacity(0.18), location: 0.0),
                        .init(color: Color.luxeEcru.opacity(0.09), location: 0.45),
                        .init(color: .clear, location: 0.90)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: width * 0.55
                )
                .frame(width: width * 1.2, height: width * 1.2)
                .position(x: width * 0.80, y: height * 0.10)
                
                // Mid-left glowing liquid orb (Luxe Bronze)
                RadialGradient(
                    stops: [
                        .init(color: Color.luxeEcru.opacity(0.15), location: 0.0),
                        .init(color: Color.luxeRichCharcoal.opacity(0.06), location: 0.50),
                        .init(color: .clear, location: 0.90)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: width * 0.50
                )
                .frame(width: width * 1.0, height: width * 1.0)
                .position(x: width * 0.20, y: height * 0.48)
                
                // Bottom-right subtle accent orb
                RadialGradient(
                    stops: [
                        .init(color: Color.luxeFlax.opacity(0.12), location: 0.0),
                        .init(color: .clear, location: 0.80)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: width * 0.45
                )
                .frame(width: width * 0.9, height: width * 0.9)
                .position(x: width * 0.70, y: height * 0.82)
            }
            .drawingGroup() // Flattens ambient light into a single Metal GPU render pass!
            .ignoresSafeArea()
        }
    }
}

// MARK: - View Extension Shortcuts
extension View {
    func liquidGlassCard(cornerRadius: CGFloat = Theme.cornerRadius) -> some View {
        self.modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius))
    }
    
    func liquidGlassPill(cornerRadius: CGFloat = 10) -> some View {
        self.modifier(LiquidGlassPillModifier(cornerRadius: cornerRadius))
    }
    
    func liquidGlassGoldButton(cornerRadius: CGFloat = 10) -> some View {
        self.modifier(LiquidGlassGoldButtonModifier(cornerRadius: cornerRadius))
    }
    
    @ViewBuilder
    func liquidGlassAdaptiveButton(isPrimary: Bool, cornerRadius: CGFloat = 10) -> some View {
        if isPrimary {
            self.modifier(LiquidGlassGoldButtonModifier(cornerRadius: cornerRadius))
        } else {
            self.modifier(LiquidGlassPillModifier(cornerRadius: cornerRadius))
        }
    }
}
