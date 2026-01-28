//
//  ClothingItem.swift
//  fitpick
//
//  Created by Bryan Gavino on 1/19/26.
//

import SwiftUI

enum ClothingCategory: String, CaseIterable, Identifiable, Codable {
    case top = "Top"
    case bottom = "Bottom"
    case shoes = "Shoes"
    
    var id: String { self.rawValue }
    
    // Icons used in the ClosetView headers
    var icon: String {
        switch self {
        case .top: return "tshirt"
        case .bottom: return "figure.walk" // Represents pants/bottoms
        case .shoes: return "shoe"
        }
    }
}

struct ClothingItem: Identifiable, Equatable {
    // We make 'id' a constant that must be passed in (for Firestore document IDs)
    let id: UUID
    
    var image: Image          // The SwiftUI Image wrapper
    var uiImage: UIImage?     // CHANGED: Optional (?) so it can be nil when loading from cloud
    var category: ClothingCategory
    var subCategory: String   // Dynamic string from AI
    var remoteURL: String     // URL from Firebase Storage
    
    // Conformance helps SwiftUI Lists animate correctly
    static func == (lhs: ClothingItem, rhs: ClothingItem) -> Bool {
        return lhs.id == rhs.id
    }
}
