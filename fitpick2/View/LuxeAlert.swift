//
//  LuxeAlert.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 2/17/26.
//

import SwiftUI

// MARK: - Reusable Luxe Alert Component (Liquid Glass)
struct LuxeAlert: View {
    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            // Dimmed, blurred backdrop — glass needs something behind it to refract
            Color.luxeBlack.opacity(0.55)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { withAnimation { onCancel() } }

            VStack(spacing: 0) {
                // Title in Gold
                Text(title)
                    .font(.system(size: 14, weight: .black))
                    .tracking(3)
                    .padding(.top, 30)
                    .foregroundColor(.luxeFlax)

                // Italicized Serif Message
                Text(message)
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(25)
                    .foregroundColor(.luxeBeige.opacity(0.85))

                Divider()
                    .background(Color.luxeEcru.opacity(0.25))
                    .padding(.horizontal, 0)

                // Action Buttons
                HStack(spacing: 0) {
                    if !cancelTitle.isEmpty {
                        Button(action: { withAnimation { onCancel() } }) {
                            Text(cancelTitle)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .frame(height: 50)
                            .background(Color.luxeEcru.opacity(0.25))
                    }

                    Button(action: { onConfirm() }) {
                        Text(confirmTitle)
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.luxeEcru)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 300)
            // Liquid Glass card — respects Reduce Transparency automatically
            .liquidGlassCard(cornerRadius: 28)
            .transition(.opacity.combined(with: .scale(scale: 0.92)))
        }
    }
}

// Uses LiquidGlassCardModifier / .liquidGlassCard() from LiquidGlass.swift —
// make sure that file is included in your target alongside this one.

// MARK: - View Extension
extension View {
    func luxeAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmTitle: String = "CONFIRM",
        cancelTitle: String = "CANCEL",
        onConfirm: @escaping () -> Void
    ) -> some View {
        ZStack {
            self
            if isPresented.wrappedValue {
                LuxeAlert(
                    title: title,
                    message: message,
                    confirmTitle: confirmTitle,
                    cancelTitle: cancelTitle,
                    onConfirm: onConfirm,
                    onCancel: { isPresented.wrappedValue = false }
                )
                .zIndex(1)
            }
        }
    }
}
