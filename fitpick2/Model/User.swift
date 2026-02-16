//
//  User.swift
//  fitpick
//
//  Created by Karry Raia Oberes on 1/15/26.
//

import Foundation
import FirebaseAuth

struct User: Identifiable, Codable {
    var id: String
    var username: String
    var selfie: String
    var bio: String?
    var following: [String] = []
}
