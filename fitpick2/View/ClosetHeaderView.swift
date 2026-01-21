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
                    .scaledToFit()
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.05))
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 250)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "person.fill.viewfinder")
                                .font(.largeTitle)
                            Text("Upload a Portrait")
                        }
                        .foregroundColor(.secondary)
                    )
            }
        }
    }
}
