//
//  WardrobeReminderService.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 2/12/26.
//

import Foundation

class WardrobeReminderService {
    private let calendar = LocalCalendarManager()
    // Use a helper method to get the current manager
    private var firestore: FirestoreManager {
        return FirestoreManager()
    }
    
    func runReminderCheck() {
        calendar.fetchNextEvent { [weak self] eventTitle in
            guard let self = self, let title = eventTitle else { return }
            
            // Use the Pulse logic from your FirestoreManager
            self.firestore.fetchWardrobePulse(lastDays: 7) { uploaded, used in
                if uploaded > 0 && used == 0 {
                    // Scenario: User has NEW clothes they haven't worn yet for this event
                    NotificationManager.shared.sendStylingReminder(
                        title: "New Outfit Opportunity!",
                        body: "You have '\(title)' coming up. Try those new items you recently added!"
                    )
                } else {
                    // Scenario: General reminder to check existing wardrobe for the event
                    NotificationManager.shared.sendStylingReminder(
                        title: "Event Reminder",
                        body: "Don't forget to pick an outfit for '\(title)' from your collection today!"
                    )
                }
            }
        }
    }
}
