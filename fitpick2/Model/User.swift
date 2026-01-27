//
//  User.swift
//  fitpick
//
//  Created by Karry Raia Oberes on 1/15/26.
//

import Foundation
import FirebaseAuth

struct User: Identifiable {
    var id: String
    var username: String
    var selfie: String
}

//class UserSession: ObservableObject {
//    @Published var email: String?
//    
//    init() {
//        // Try Firebase Auth first, then fallback to persisted Google sign-in email
//        if let firebaseEmail = Auth.auth().currentUser?.email {
//            self.email = firebaseEmail
//        } else if let persisted = UserDefaults.standard.string(forKey: "signedInEmail") {
//            self.email = persisted
//        } else {
//            self.email = nil
//        }
//    }
//}
