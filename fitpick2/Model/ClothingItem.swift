//
//  ClothingItem.swift
//  fitpick
//
//  Created by Bryan Gavino on 1/19/26.
//

import SwiftUI
import FirebaseFirestore

// 1. Update the Struct to include 'size'
struct ClothingItem: Identifiable {
    let id: String
    let image: Image // Note: We don't usually store 'Image' in Codable, but keeping your existing pattern
    let uiImage: UIImage? // Optional for local use
    let category: ClothingCategory
    let subCategory: String
    let remoteURL: String
    // --- NEW PROPERTY ---
    var size: String = ""
    // Default to empty string so old items without a size don't crash the app
}

struct AICategorization: Codable {
    let category: String
    let subcategory: String
    let size: String
}

// 2. Make sure your Category Enum is available too
enum ClothingCategory: String, CaseIterable, Codable, Identifiable {
    case top = "Top"
    case bottom = "Bottom"
    case shoes = "Shoes"
    case accessories = "Accessories"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .top: return "tshirt"
        case .bottom: return "figure.walk"
        case .shoes: return "shoe"
        case .accessories: return "bag"
        }
    }
}
