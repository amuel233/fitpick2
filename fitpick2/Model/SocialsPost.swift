//
//  SocialsPost.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 1/27/26.
//

import Foundation
import FirebaseFirestore

struct SocialsPost: Identifiable, Codable {
    var id: String
    var userEmail: String
    var username: String
    var caption: String
    var imageUrl: String
    var likes: Int
    //Tracks emails for backend logic (unique identification)
    var likedBy: [String]?
    //Tracks usernames for frontend display
    var likedByNames: [String]?
    var timestamp: Date
    // Helpers to prevent crashes if the fields are missing in Firestore
    var safeLikedBy: [String] { likedBy ?? [] }
    var safeLikedByNames: [String] { likedByNames ?? [] }
}
