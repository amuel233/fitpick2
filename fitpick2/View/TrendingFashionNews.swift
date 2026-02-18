//
//  TrendingFashionNews.swift
//  fitpick2
//
//  Created by Shakira Mhaire on 1/19/26.
//

import SwiftUI

struct TrendingFashionNews: View {
    @State private var articles: [Article] = []
    @State private var loading = true
    @State private var locality: String? = nil
    private let news = NewsManager()
    private let weather = WeatherManager()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundColor(.luxeFlax) // Updated to Luxe Gold
                Text("Trending in Fashion")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.luxeBeige) // Updated to Luxe Beige
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }

            if loading {
                Text("Loading articles...")
                    .font(.subheadline)
                    .foregroundColor(.luxeBeige.opacity(0.6)) // Updated branding
                    .padding(.vertical, 8)
            } else if articles.isEmpty {
                Text("No trending articles found.")
                    .font(.subheadline)
                    .foregroundColor(.luxeBeige.opacity(0.6)) // Updated branding
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(articles) { a in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(a.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundColor(.luxeBeige) // Updated branding
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                
                                Text(a.source)
                                    .font(.caption)
                                    .foregroundColor(.luxeFlax) // Updated to accent color
                                
                                Button(action: {
                                    if let url = URL(string: a.url) {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    Text("Read More")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(.luxeBlack)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(Color.luxeGoldGradient) // Updated branding
                                        .cornerRadius(6)
                                }
                            }
                            .frame(width: 200, alignment: .leading)
                            .padding(12)
                            .background(Color.luxeRichCharcoal.opacity(0.5)) // Darker sub-card
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.luxeEcru.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
        .padding(Theme.cardPadding)
        .background(Color.luxeRichCharcoal.opacity(0.8)) // Main Luxe card background
        .cornerRadius(Theme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Color.luxeEcru.opacity(0.2), lineWidth: 1)
        )
        .onAppear(perform: loadArticles)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HomeDidRefresh"))) { _ in
            loadArticles()
        }
    }

    // MARK: - Logic (Unaffected)
    private func loadArticles() {
        loading = true
        weather.requestLocation { res in
            switch res {
            case .success((let lat, let lon)):
                self.weather.reverseGeocode(lat: lat, lon: lon) { r in
                    switch r {
                    case .success(let locality):
                        self.locality = locality
                        self.fetch(locality: locality)
                    case .failure(_):
                        self.fetch(locality: nil)
                    }
                }
            case .failure(_):
                self.fetch(locality: nil)
            }
        }
    }

    private func fetch(locality: String?) {
        news.fetchTrending(for: locality) { res in
            switch res {
            case .success(let arr):
                self.articles = arr
            case .failure(_):
                self.articles = []
            }
            self.loading = false
        }
    }
}

struct TrendingFashionNews_Previews: PreviewProvider {
    static var previews: some View { TrendingFashionNews().preferredColorScheme(.dark).padding() }
}
