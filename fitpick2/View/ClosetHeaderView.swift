//
//  ClosetHeaderView.swift
//  fitpick
//
//  Created by Bryan Gavino on 1/19/26.
//

import SwiftUI

struct ClosetHeaderView: View {
    let portraitImage: Image?

    var body: some View {
        ZStack {
            if let portraitImage {
                portraitImage
                    .resizable()
                    .scaledToFit() // Ensures the full person is visible without cropping
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.05))
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.6)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
            } else {
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 250)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "person.fill.viewfinder")
                                .font(.largeTitle)
                            Text("Upload Portrait")
                                .font(.headline)
                        }
                        .foregroundColor(.secondary)
                    )
            }

            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(portraitImage == nil ? "My Profile" : "Virtual Mirror Ready")
                            .font(.headline)
                            .foregroundColor(portraitImage == nil ? .primary : .white)
                        
                        Text(portraitImage == nil ? "Tap to add a photo of yourself" : "Use 'Try On' to see your clothes")
                            .font(.caption)
                            .foregroundColor(portraitImage == nil ? .secondary : .white.opacity(0.8))
                    }
                    Spacer()
                }
                .padding()
            }
        }
    }
}
