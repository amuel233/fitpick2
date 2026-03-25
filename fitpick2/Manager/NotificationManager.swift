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
        
        // Save to Firestore only if it's a new token
        saveTokenToUserDocument(token: token)
    }
    
    private func saveTokenToUserDocument(token: String) {
        // Prevent redundant writes if the token hasn't changed
        let lastToken = UserDefaults.standard.string(forKey: "lastSavedFCMToken")
        guard token != lastToken else {
            print("Token unchanged, skipping Firestore update.")
            return
        }

        guard let email = Auth.auth().currentUser?.email else { return }
        let db = Firestore.firestore()
        
        db.collection("users").document(email.lowercased()).updateData([
            "fcmToken": token
        ]) { error in
            if let error = error {
                print("Error saving FCM token: \(error.localizedDescription)")
            } else {
                UserDefaults.standard.set(token, forKey: "lastSavedFCMToken")
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
