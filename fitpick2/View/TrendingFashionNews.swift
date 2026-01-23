//
//  TrendingFashionNews.swift
//  fitpick2
//
//  Created by Shakira Mhaire on 1/19/26.
//
import SwiftUI

struct TrendingFashionNews: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                Text("Trending This Week")
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(0..<5) { i in
                        VStack(alignment: .leading, spacing: 10) {
                            RoundedRectangle(cornerRadius: Theme.cornerRadius - 4)
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.blue.opacity(0.1),
                                        Color.purple.opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 160, height: 100)
                                .overlay(
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.yellow)
                                        .font(.title2)
                                )
                            Text("Trend \(i + 1)")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(Theme.cardPadding)
        .background(.regularMaterial)
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 2)
    }
}

struct TrendingFashionNews_Previews: PreviewProvider {
    static var previews: some View { TrendingFashionNews().preferredColorScheme(.dark).padding() }
}
