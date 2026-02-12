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
                    .foregroundColor(.yellow)
                Text("Trending in Fashion")
                    .font(.headline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }

            if loading {
                Text("Loading articles...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else if articles.isEmpty {
                Text("No trending articles found.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(articles) { a in
                            VStack(alignment: .leading, spacing: 8) {
                                RoundedRectangle(cornerRadius: Theme.cornerRadius - 4)
                                    .fill(LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.blue.opacity(0.08),
                                            Color.purple.opacity(0.08)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 220, height: 110)
                                    .overlay(
                                        Image(systemName: "newspaper.fill")
                                            .foregroundColor(.yellow)
                                            .font(.title2)
                                    )

                                Text(a.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(a.source)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 220)
                            .onTapGesture {
                                if let url = URL(string: a.url) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding(Theme.cardPadding)
        .background(.regularMaterial)
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 2)
        .onAppear(perform: loadArticles)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HomeDidRefresh"))) { _ in
            loadArticles()
        }
    }

    private func loadArticles() {
        loading = true
        // Use WeatherManager to reverse geocode locality if possible
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
