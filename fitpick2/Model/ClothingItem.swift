//
//  ClothingItem.swift
//  fitpick
//
//  Created by Bryan Gavino on 1/19/26.
//

import SwiftUI

enum ClothingCategory: String, CaseIterable, Identifiable {
    case top = "Top"
    case bottom = "Bottom"
    case shoes = "Shoes"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .top: return "tshirt"
        case .bottom: return "figure.walk"
        case .shoes: return "shoe"
        }
    }
    
    // Function to provide sub-categories based on gender
    func subCategories(for gender: String) -> [String] {
        switch (self, gender) {
        case (.top, "Male"):
            return ["T-Shirt", "Polo", "Polo Shirt", "Sando"]
        case (.top, "Female"):
            return ["T-Shirt", "Blouse", "Dress", "Cropped Top"]
        case (.bottom, _):
            return ["Shorts", "Pants"]
        case (.shoes, "Male"):
            return ["Sneakers", "Slippers", "Clogs"]
        case (.shoes, "Female"):
            return ["Sneakers", "Slippers", "Heels"]
        default:
            return []
        }
    }
}

struct ClothingItem: Identifiable, Equatable {
    let id = UUID()
    let image: Image
    let uiImage: UIImage
    let category: ClothingCategory
    let subCategory: String // Added sub-category field
    var remoteURL: String? = nil

    static func == (lhs: ClothingItem, rhs: ClothingItem) -> Bool {
        lhs.id == rhs.id
    }
}
