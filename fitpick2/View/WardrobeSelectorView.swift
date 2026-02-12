//
//  WardrobeSelectorView.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 2/9/26.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct WardrobeItem: Identifiable {
    let id: String
    let imageURL: String
    let category: String
    let subcategory: String
}

struct WardrobeSelectorView: View {
    @Binding var selectedItems: Set<String>
    @State private var wardrobe: [WardrobeItem] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @Environment(\.dismiss) var dismiss
    
    // Theme Colors
    let fitPickGold = Color("fitPickGold")
    let fitPickWhite = Color(red: 245/255, green: 245/255, blue: 247/255)

    // Filter Logic updated to search by subcategory
    private var filteredWardrobe: [WardrobeItem] {
        if searchText.isEmpty {
            return wardrobe
        } else {
            return wardrobe.filter { $0.subcategory.localizedCaseInsensitiveContains(searchText) }
        }
    }

    // Items remain grouped by the main category for the layout
    private var groupedWardrobe: [String: [WardrobeItem]] {
        Dictionary(grouping: filteredWardrobe, by: { $0.category })
    }
    
    private var categories: [String] {
        groupedWardrobe.keys.sorted()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                fitPickWhite.ignoresSafeArea()
                
                if isLoading {
                    ProgressView().tint(fitPickGold)
                } else if wardrobe.isEmpty {
                    emptyStateView(title: "Your closet is empty", sub: "Upload clothes to your wardrobe first.")
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 30) {
                            ForEach(categories, id: \.self) { category in
                                categoryCarouselSection(category: category)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Select Items")
            .navigationBarTitleDisplayMode(.inline)
            // Updated prompt to reflect subcategory search
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search subcategories (e.g. Vintage, Denim)...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundColor(fitPickGold)
                }
            }
            .onAppear(perform: fetchUserClothes)
        }
    }

    // MARK: - Carousel Section
    @ViewBuilder
    private func categoryCarouselSection(category: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(category.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(groupedWardrobe[category]?.count ?? 0) items")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    if let items = groupedWardrobe[category] {
                        ForEach(items) { item in
                            wardrobeItemCard(item: item)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 5)
            }
        }
    }

    @ViewBuilder
    private func wardrobeItemCard(item: WardrobeItem) -> some View {
        let isSelected = selectedItems.contains(item.id)
        
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: item.imageURL)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        Color.gray.opacity(0.1)
                        ProgressView().scaleEffect(0.8)
                    }
                }
                .frame(width: 120, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(isSelected ? fitPickGold : Color.black.opacity(0.05), lineWidth: isSelected ? 3 : 1)
                )
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, fitPickGold)
                        .font(.system(size: 22))
                        .offset(x: 6, y: -6)
                }
            }
            
            // Added subcategory label below the image for clarity
            Text(item.subcategory)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 4)
        }
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if isSelected {
                selectedItems.remove(item.id)
            } else {
                selectedItems.insert(item.id)
            }
        }
    }

    private func emptyStateView(title: String, sub: String) -> some View {
        VStack(spacing: 15) {
            Image(systemName: "tshirt")
                .font(.system(size: 50))
                .foregroundColor(fitPickGold.opacity(0.5))
            Text(title).font(.headline)
            Text(sub).font(.subheadline).foregroundColor(.secondary)
        }
    }

    // MARK: - Data Fetching
    private func fetchUserClothes() {
        guard let email = Auth.auth().currentUser?.email else {
            isLoading = false
            return
        }
        
        Firestore.firestore().collection("clothes")
            .whereField("ownerEmail", isEqualTo: email)
            .getDocuments { snap, error in
                if let error = error {
                    print("Firestore Error: \(error.localizedDescription)")
                }
                
                self.wardrobe = snap?.documents.compactMap { doc in
                    let data = doc.data()
                    return WardrobeItem(
                        id: doc.documentID,
                        imageURL: data["imageURL"] as? String ?? "",
                        category: data["category"] as? String ?? "Other",
                        subcategory: data["subcategory"] as? String ?? "General" // Fetching subcategory from Firestore
                    )
                } ?? []
                
                isLoading = false
            }
    }
}
