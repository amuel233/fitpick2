//
//  NotificationManager.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 2/12/26.
//

import UIKit
import Foundation
import UserNotifications
import FirebaseMessaging
import FirebaseAuth
import FirebaseFirestore

class NotificationManager: NSObject, MessagingDelegate, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private let reminderService = WardrobeReminderService()
    
    func requestPermissions() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
        Messaging.messaging().delegate = self
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("✅ Firebase registration token is ready: \(token)")
        
        // Save to Firestore
        saveTokenToUserDocument(token: token)
        
        // Run the smart check and notify the app to schedule the background task
        reminderService.runReminderCheck { nextRun in
            DispatchQueue.main.async {
                // Safely call back to AppDelegate to schedule the next wake-up
                (UIApplication.shared.delegate as? AppDelegate)?.scheduleAppRefresh(at: nextRun)
            }
        }
    }
    
    private func saveTokenToUserDocument(token: String) {
        guard let email = Auth.auth().currentUser?.email else { return }
        let db = Firestore.firestore()
        
        db.collection("users").document(email.lowercased()).updateData([
            "fcmToken": token
        ]) { error in
            if let error = error {
                print("Error saving FCM token: \(error.localizedDescription)")
            } else {
                print("FCM Token successfully saved for \(email)")
            }
        }
    }
    
    func subscribeToWardrobeReminders() {
        guard !UserDefaults.standard.bool(forKey: "isSubscribedToWardrobe") else { return }
        
        Messaging.messaging().subscribe(toTopic: "wardrobe_reminders") { error in
            if error == nil {
                UserDefaults.standard.set(true, forKey: "isSubscribedToWardrobe")
                print("🔔 Topic Subscribed")
            }
        }
    }

    func unsubscribeFromWardrobeReminders() {
        guard UserDefaults.standard.bool(forKey: "isSubscribedToWardrobe") else { return }
        
        Messaging.messaging().unsubscribe(fromTopic: "wardrobe_reminders") { error in
            if error == nil {
                UserDefaults.standard.set(false, forKey: "isSubscribedToWardrobe")
                print("🔕 Topic Unsubscribed")
            }
        }
    }
}
