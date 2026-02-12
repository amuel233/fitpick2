//
//  WardrobeReminderService.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 2/12/26.
//

import Foundation
import EventKit

class WardrobeReminderService {
    private let calendar = LocalCalendarManager()
    
    // Returns the date of the next event end-time for scheduling
    func runReminderCheck(completion: @escaping (Date?) -> Void) {
        calendar.fetchAllUpcomingEvents { events in
            let now = Date()
            let activeEvents = events.filter { $0.endDate > now }
            
            // Find the milestone (earliest end time of current events)
            let nextMilestone = activeEvents.map { $0.endDate }.min()
            
            // Smart Subscription Management
            let isAlreadySubscribed = UserDefaults.standard.bool(forKey: "isSubscribedToWardrobe")
            
            if !activeEvents.isEmpty {
                if !isAlreadySubscribed {
                    NotificationManager.shared.subscribeToWardrobeReminders()
                    UserDefaults.standard.set(true, forKey: "isSubscribedToWardrobe")
                    print("✅ New events found: Subscribing.")
                } else {
                    print("⏳ Active: \(activeEvents.count) events remaining. Stay subscribed.")
                }
            } else {
                if isAlreadySubscribed {
                    NotificationManager.shared.unsubscribeFromWardrobeReminders()
                    UserDefaults.standard.set(false, forKey: "isSubscribedToWardrobe")
                    print("🧹 All events finished: Unsubscribing.")
                }
            }
            
            // Return 1 min after the next event ends, or nil if no events left
            let suggestedNextRun = nextMilestone?.addingTimeInterval(60)
            completion(suggestedNextRun)
        }
    }
}
