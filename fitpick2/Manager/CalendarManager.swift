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
    /// Fetch next event with parsed start Date (if available)
    func fetchNextEventDetail(completion: @escaping (String?, Date?) -> Void) {
        if let user = GIDSignIn.sharedInstance.currentUser {
            let accessToken = user.accessToken.tokenString
            let urlString = "https://www.googleapis.com/calendar/v3/calendars/primary/events?maxResults=1&orderBy=startTime&singleEvents=true&timeMin=\(Date().iso8601String)"
            guard let url = URL(string: urlString) else { DispatchQueue.main.async { completion(nil, nil) }; return }

            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: req) { data, response, error in
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let items = json["items"] as? [[String: Any]],
                      let first = items.first else {
                    DispatchQueue.main.async { completion(nil, nil) }
                    return
                }

                let summary = first["summary"] as? String
                    let descriptionText = first["description"] as? String
                if let start = first["start"] as? [String: Any] {
                    let timeString = (start["dateTime"] as? String) ?? (start["date"] as? String)
                    var eventText: String? = nil
                    var dateObj: Date? = nil
                        // Prefer description (notes) from the calendar event; fall back to summary/title
                        if let desc = descriptionText, !desc.isEmpty {
                            eventText = desc
                        } else if let summary = summary {
                            eventText = summary
                    }

                    // parse ISO date/time
                    if let timeString = timeString {
                        if let d = ISO8601DateFormatter().date(from: timeString) {
                            dateObj = d
                        } else {
                            let df = DateFormatter()
                            df.dateFormat = "yyyy-MM-dd"
                            dateObj = df.date(from: timeString)
                        }
                    }

                    DispatchQueue.main.async { completion(eventText, dateObj) }
                    return
                }

                    // If no start time, still prefer description over summary
                    let content = (descriptionText != nil && !(descriptionText!.isEmpty)) ? descriptionText : summary
                    DispatchQueue.main.async { completion(content, nil) }
            }.resume()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                completion("Dinner at 8 PM — Formal", Date().addingTimeInterval(3600*24))
            }
        }
    }
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
                let descriptionText = first["description"] as? String
                if let start = first["start"] as? [String: Any] {
                    let timeString = (start["dateTime"] as? String) ?? (start["date"] as? String)
                    // Prefer description (notes) from the calendar event; fall back to summary/title
                    let eventText: String?
                    if let desc = descriptionText, !desc.isEmpty {
                        eventText = desc
                    } else if let summary = summary, let timeString = timeString {
                        eventText = summary
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

    /// Fetch all upcoming events within the next `daysAhead + 1` days (default: today only)
    func fetchUpcomingEvents(daysAhead: Int = 0, completion: @escaping ([(title: String, description: String?, date: Date?)]) -> Void) {
        if let user = GIDSignIn.sharedInstance.currentUser {
            let accessToken = user.accessToken.tokenString
            let now = Date()
            let startIso = now.iso8601String
            let endDate = Calendar.current.startOfDay(for: now).addingTimeInterval(Double(daysAhead + 1) * 86400)
            let endIso = endDate.iso8601String
            let urlString = "https://www.googleapis.com/calendar/v3/calendars/primary/events?maxResults=50&orderBy=startTime&singleEvents=true&timeMin=\(startIso)&timeMax=\(endIso)"
            guard let url = URL(string: urlString) else { DispatchQueue.main.async { completion([]) }; return }

            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: req) { data, response, error in
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let items = json["items"] as? [[String: Any]] else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }

                var results: [(title: String, description: String?, date: Date?)] = []
                for item in items {
                    let summary = item["summary"] as? String
                    let descriptionText = item["description"] as? String
                    var dateObj: Date? = nil
                    if let start = item["start"] as? [String: Any] {
                        let timeString = (start["dateTime"] as? String) ?? (start["date"] as? String)
                        if let ts = timeString {
                            if let d = ISO8601DateFormatter().date(from: ts) {
                                dateObj = d
                            } else {
                                let df = DateFormatter()
                                df.dateFormat = "yyyy-MM-dd"
                                dateObj = df.date(from: ts)
                            }
                        }
                    }

                    let content = (descriptionText != nil && !(descriptionText!.isEmpty)) ? descriptionText : summary
                    let title = content ?? "Event"
                    results.append((title: title, description: descriptionText, date: dateObj))
                }

                DispatchQueue.main.async { completion(results) }
            }.resume()
        } else {
            // Stubbed multiple events for preview / unsigned state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let d1 = Date().addingTimeInterval(3600 * 3)
                let d2 = Date().addingTimeInterval(3600 * 6)
                completion([("Team meeting — Planning", nil, d1), ("Dinner with friends — Casual", nil, d2)])
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

