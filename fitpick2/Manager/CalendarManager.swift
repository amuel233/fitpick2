//
//  CalendarManager.swift
//  fitpick2
//
//  Created by Shakira Mhaire on 1/19/26.
//
import Foundation
import GoogleSignIn

extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}

class CalendarManager {
    func fetchNextEvent(completion: @escaping (String?) -> Void) {
        if let user = GIDSignIn.sharedInstance.currentUser {
            let accessToken = user.accessToken.tokenString
            
            let urlString = "https://www.googleapis.com/calendar/v3/calendars/primary/events?maxResults=1&orderBy=startTime&singleEvents=true&timeMin=\(Date().iso8601String)"
            
            guard let url = URL(string: urlString) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

                        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let items = json["items"] as? [[String: Any]],
                      let first = items.first else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }

                let summary = first["summary"] as? String
                if let start = first["start"] as? [String: Any] {
                    let timeString = (start["dateTime"] as? String) ?? (start["date"] as? String)
                    let eventText: String?
                    if let summary = summary, let timeString = timeString {
                        let formatted = self?.formatTime(timeString) ?? timeString
                        eventText = "\(summary) at \(formatted)"
                    } else if let summary = summary {
                        eventText = summary
                    } else {
                        eventText = nil
                    }
                    DispatchQueue.main.async { completion(eventText) }
                    return
                }

                DispatchQueue.main.async { completion(summary) }
            }.resume()

        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                completion("Dinner at 8 PM — Formal")
            }
        }
    }

    private func formatTime(_ iso: String) -> String {
        let formats = ["yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd"]
        for f in formats {
            let df = DateFormatter()
            df.dateFormat = f
            if let d = df.date(from: iso) {
                let out = DateFormatter()
                out.timeStyle = .short
                return out.string(from: d)
            }
        }
        return iso
    }
}

