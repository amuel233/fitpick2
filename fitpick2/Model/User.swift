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

class UserSession: ObservableObject {
    @Published var email: String?
    
    init() {
        // Automatically check if a user is already signed in
        self.email = Auth.auth().currentUser?.email
    }
}
