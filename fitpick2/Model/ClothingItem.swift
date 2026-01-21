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
}

struct ClothingItem: Identifiable, Equatable {
    let id = UUID() // Unique identifier for every single upload
    let image: Image
    let uiImage: UIImage
    let category: ClothingCategory
    
    // Allows SwiftUI to compare two items and see if they are the exact same one
    static func == (lhs: ClothingItem, rhs: ClothingItem) -> Bool {
        lhs.id == rhs.id
    }
}
