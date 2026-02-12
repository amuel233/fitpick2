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
        
        // Now that we HAVE a token, we can safely subscribe without the APNS error
        self.subscribeToWardrobeReminders()
        
        // Save this token to Firestore so you can target this user later
        saveTokenToUserDocument(token: token)
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

    // Sends a reminder to the user's screen
    func sendStylingReminder(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // We use a unique ID so reminders for different events don't overwrite each other
        let request = UNNotificationRequest(
            identifier: "wardrobe_reminder_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func subscribeToWardrobeReminders() {
        Messaging.messaging().subscribe(toTopic: "wardrobe_reminders") { error in
            if let error = error {
                print("❌ Error subscribing to wardrobe_reminders: \(error.localizedDescription)")
            } else {
                print("✅ Successfully subscribed to wardrobe_reminders!")
            }
        }
    }
}
