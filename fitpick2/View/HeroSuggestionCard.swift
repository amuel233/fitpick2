//
//  HeroSuggestionCard.swift
//  fitpick2
//
//  Created by Shakira Mhaire on 1/19/26.
//
import SwiftUI
struct HeroSuggestionCard: View {
    var outfitImage: String?

    var body: some View {
        VStack(spacing: Theme.cardSpacing) {
                if let outfitImage = outfitImage, let url = URL(string: outfitImage),
                    let scheme = url.scheme?.lowercased(), (scheme == "http" || scheme == "https") {
                // AsyncImage will download and cache the image automatically on iOS 15+
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: 300)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: 380)
                            .clipped()
                            .cornerRadius(Theme.cornerRadius - 6)
                    case .failure:
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 180)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else if let name = outfitImage {
                Image(name)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: 380)
                    .clipped()
                    .cornerRadius(Theme.cornerRadius - 6)
            } else {
                RoundedRectangle(cornerRadius: Theme.cornerRadius - 6)
                    .fill(Color.secondary.opacity(0.06))
                    .frame(height: 350)
                    .overlay(Image(systemName: "photo.on.rectangle.angled").font(.largeTitle))
            }

            EmptyView()
        }
        .padding(Theme.cardPadding)
        .background(.regularMaterial)
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: Theme.cardShadow, radius: 6, x: 0, y: 3)
    }
}

struct HeroSuggestionCard_Previews: PreviewProvider {
    static var previews: some View {
        HeroSuggestionCard(outfitImage: nil)
            .preferredColorScheme(.dark)
            .padding()
    }
}
