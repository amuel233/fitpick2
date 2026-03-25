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
    let remoteURL: String
    let category: ClothingCategory
    let subCategory: String
    var size: String = ""
    
    // ✅ FIX 1: Added missing fields (Fixes "Extra arguments" error)
    var ownerEmail: String
    var dateAdded: Date
    
    // CodingKeys map JSON keys if they differ from variable names
    enum CodingKeys: String, CodingKey {
        case id
        case remoteURL
        case category
        case subCategory
        case size
        case ownerEmail
        case dateAdded = "createdat" // ✅ Maps Firestore 'createdat' to Swift 'dateAdded'
    }
    
    // ✅ FIX 2: Custom Decoder to handle missing fields gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(String.self, forKey: .id)
        self.remoteURL = try container.decode(String.self, forKey: .remoteURL)
        
        // Safe Category Decoding
        if let catString = try? container.decode(String.self, forKey: .category),
           let cat = ClothingCategory(rawValue: catString) {
            self.category = cat
        } else {
            self.category = .top // Default fallback
        }
        
        self.subCategory = try container.decodeIfPresent(String.self, forKey: .subCategory) ?? "Clothing"
        self.size = try container.decodeIfPresent(String.self, forKey: .size) ?? ""
        self.ownerEmail = try container.decodeIfPresent(String.self, forKey: .ownerEmail) ?? ""
        
        // Handle Date (createdat)
        if let date = try? container.decodeIfPresent(Date.self, forKey: .dateAdded) {
            self.dateAdded = date
        } else {
            self.dateAdded = Date() // Default to now if missing
        }
    }
    
    // Memberwise Initializer
    init(id: String, remoteURL: String, category: ClothingCategory, subCategory: String, size: String, ownerEmail: String, dateAdded: Date) {
        self.id = id
        self.remoteURL = remoteURL
        self.category = category
        self.subCategory = subCategory
        self.size = size
        self.ownerEmail = ownerEmail
        self.dateAdded = dateAdded
    }
}

// MARK: - 2. Saved Look Model
// ✅ FIX 3: Added here to prevent "Invalid Redeclaration" errors
struct SavedLook: Identifiable, Codable {
    let id: String
    let imageURL: String
    let date: Date
    let itemsUsed: [String]
    
    // Optional: Computed property for formatting date
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - 3. AI Helper Models
struct AICategorization: Codable {
    let category: String
    let subcategory: String
    let size: String
}

// MARK: - 4. Bulk Upload Draft Model
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

// MARK: - 5. Centralized Category Logic
enum ClothingCategory: String, CaseIterable, Codable, Identifiable {
    case top = "Top"
    case bottom = "Bottom"
    case shoes = "Shoes"
    case accessories = "Accessories"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .top:
            return "tshirt" // Ensure "tshirt" exists in Assets or use "tshirt.fill" (SF Symbol)
        case .bottom:
            return "icon-pants" // Ensure "icon-pants" exists in Assets
        case .shoes:
            return "shoe" // Ensure "shoe" exists or use "shoe.fill" (SF Symbol)
        case .accessories:
            return "bag" // Ensure "bag" exists or use "bag.fill" (SF Symbol)
        }
    }
}
