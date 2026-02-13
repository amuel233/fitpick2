//
//  ClothingItem.swift
//  fitpick
//
//  Created by Bryan Gavino on 1/19/26.
//

import SwiftUI
import FirebaseFirestore

// MARK: - 1. Core Data Model
struct ClothingItem: Identifiable, Codable {
    let id: String
    // Note: We keep 'remoteURL' as the source of truth for the image.
    // 'uiImage' is only for local previews before upload.
    let remoteURL: String
    
    let category: ClothingCategory
    let subCategory: String
    var size: String = "" // Added support for size
    
    // CodingKeys allows us to map JSON keys if they differ from variable names
    // (Optional, but good practice for Firestore)
    enum CodingKeys: String, CodingKey {
        case id
        case remoteURL
        case category
        case subCategory
        case size
    }
}

// MARK: - 2. AI Helper Models
struct AICategorization: Codable {
    let category: String
    let subcategory: String
    let size: String
}

// MARK: - 3. Bulk Upload Draft Model
// Moved here from BulkAddItemViewModel so all models are together.
struct DraftItem: Identifiable {
    let id = UUID()
    let image: UIImage
    
    // Editable Fields
    var category: ClothingCategory = .top
    var subCategory: String = ""
    var size: String = ""
    
    // Validation State
    var isValidating: Bool = true
    var isClothing: Bool = false
    var validationMessage: String = "Checking..."
}

// MARK: - 4. Centralized Category Logic
enum ClothingCategory: String, CaseIterable, Codable, Identifiable {
    case top = "Top"
    case bottom = "Bottom"
    case shoes = "Shoes"
    case accessories = "Accessories"
    
    var id: String { self.rawValue }
    
    // FIXED: Centralized Icon Logic
    // Now you can just use `category.icon` anywhere in the app!
    var icon: String {
        switch self {
        case .top:
            return "tshirt"
        case .bottom:
            // Use your Custom Asset name here if you added it,
            // otherwise use the safe system symbol:
            return "rectangle.portrait.bottomhalf.filled"
            // return "icon-pants" // <-- Use this if you added the SVG asset
        case .shoes:
            return "shoe"
        case .accessories:
            return "bag"
        }
    }
}
