//
//  LocalCalendarManager.swift
//  fitpick2
//
//  Created by GitHub Copilot on 2026-01-30.

import Foundation
import EventKit

/// Helper to access the device's calendars and return the next upcoming event summary.
class LocalCalendarManager {
    private let store = EKEventStore()

    func fetchNextEvent(completion: @escaping (String?) -> Void) {
        store.requestAccess(to: .event) { granted, error in
            guard granted else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let calendars = self.store.calendars(for: .event)
            let now = Date()
            let oneMonth = Calendar.current.date(byAdding: .month, value: 1, to: now) ?? Date().addingTimeInterval(7*24*60*60)
            let predicate = self.store.predicateForEvents(withStart: now, end: oneMonth, calendars: calendars)
            let events = self.store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

            if let next = events.first {
                let title = next.title ?? "Event"
                let notes = next.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
                let content = (notes != nil && !notes!.isEmpty) ? notes : title
                DispatchQueue.main.async { completion(content) }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    func fetchNextEventDetail(completion: @escaping (String?, Date?) -> Void) {
        store.requestAccess(to: .event) { granted, error in
            guard granted else {
                DispatchQueue.main.async { completion(nil, nil) }
                return
            }

            let calendars = self.store.calendars(for: .event)
            let now = Date()
            let oneMonth = Calendar.current.date(byAdding: .month, value: 1, to: now) ?? Date().addingTimeInterval(7*24*60*60)
            let predicate = self.store.predicateForEvents(withStart: now, end: oneMonth, calendars: calendars)
            let events = self.store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

            if let next = events.first {
                let title = next.title ?? "Event"
                let notes = next.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
                let content = (notes != nil && !notes!.isEmpty) ? notes : title
                DispatchQueue.main.async { completion(content, next.startDate) }
            } else {
                DispatchQueue.main.async { completion(nil, nil) }
            }
        }
    }
    
    // NEW: Function to fetch all events in a specific window  --- START
    func fetchAllUpcomingEvents(completion: @escaping ([EKEvent]) -> Void) {
        if #available(iOS 17.0, *) {
            store.requestFullAccessToEvents { granted, error in
                self.processFetch(granted: granted, completion: completion)
            }
        } else {
            store.requestAccess(to: .event) { granted, error in
                self.processFetch(granted: granted, completion: completion)
            }
        }
    }

    private func processFetch(granted: Bool, completion: @escaping ([EKEvent]) -> Void) {
        guard granted else {
            print("❌ Calendar access denied")
            completion([])
            return
        }

        let now = Date()
        let endOfDay = Calendar.current.startOfDay(for: now).addingTimeInterval(86400)
        let predicate = store.predicateForEvents(withStart: now, end: endOfDay, calendars: nil)
        let events = store.events(matching: predicate)
        
        DispatchQueue.main.async { completion(events) }
    }
    // --- END

    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }
}
