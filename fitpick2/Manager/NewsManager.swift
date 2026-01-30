//
//  NewsManager.swift
//  fitpick2
//
//  Created by GitHub Copilot on 2026-01-30.
//

import Foundation

struct Article: Identifiable, Codable {
    let id = UUID()
    let title: String
    let source: String
    let url: String
}

/// Small manager that fetches trending fashion articles for a locality.
///
/// If the app provides a `NEWS_API_KEY` in Info.plist, this will call NewsAPI.org.
/// Otherwise it returns a set of mocked notable-fashion sources as a graceful fallback.
class NewsManager {
    private let session = URLSession.shared

    func fetchTrending(for locality: String?, completion: @escaping (Result<[Article], Error>) -> Void) {
        // Try to read API key from Info.plist
        let key = Bundle.main.object(forInfoDictionaryKey: "NEWS_API_KEY") as? String
        let queryLocation = (locality?.isEmpty == false) ? locality! : ""
        let q = "fashion \(queryLocation)".trimmingCharacters(in: .whitespaces)

        guard let apiKey = key, !apiKey.isEmpty else {
            // No API key: return mocked articles from notable outlets
            let samples: [Article] = [
                Article(title: "Street Style Roundup: What Influencers Are Wearing This Week", source: "Vogue", url: "https://www.vogue.com"),
                Article(title: "Sustainable Brands Gaining Traction in 2026", source: "Business of Fashion", url: "https://www.businessoffashion.com"),
                Article(title: "Local Designers to Watch in \(queryLocation)", source: "Local Fashion", url: "https://www.example.com/local-fashion"),
                Article(title: "Ten Comfortable Shoes That Look Professional", source: "GQ", url: "https://www.gq.com"),
                Article(title: "How Weather Is Shaping Winter 2026 Trends", source: "WWD", url: "https://www.wwd.com")
            ]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { completion(.success(samples)) }
            return
        }

        // Build NewsAPI.org query
        let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "fashion"
        let urlString = "https://newsapi.org/v2/everything?q=\(encoded)&sortBy=publishedAt&pageSize=6&apiKey=\(apiKey)"
        guard let url = URL(string: urlString) else { completion(.failure(NSError(domain: "news", code: 0))); return }

        session.dataTask(with: url) { data, resp, err in
            if let err = err { DispatchQueue.main.async { completion(.failure(err)) }; return }
            guard let data = data else { DispatchQueue.main.async { completion(.success([])) }; return }

            do {
                let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let items = root?["articles"] as? [[String: Any]] ?? []
                let articles: [Article] = items.compactMap { it in
                    let title = it["title"] as? String
                    let source = (it["source"] as? [String: Any])?["name"] as? String
                    let url = it["url"] as? String
                    if let t = title {
                        return Article(title: t, source: source ?? "Unknown", url: url ?? "")
                    }
                    return nil
                }
                DispatchQueue.main.async { completion(.success(articles)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }
}
