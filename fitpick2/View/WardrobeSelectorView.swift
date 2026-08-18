//
//  WardrobeSelectorView.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 2/9/26.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Kingfisher

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
    
    // MARK: - Luxe Brand Assets
    let luxeGold = Color.luxeFlax
    let luxeBronze = Color.luxeEcru

    // Unaffected Filter Logic
    private var filteredWardrobe: [WardrobeItem] {
        if searchText.isEmpty {
            return wardrobe
        } else {
            return wardrobe.filter { $0.subcategory.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var groupedWardrobe: [String: [WardrobeItem]] {
        Dictionary(grouping: filteredWardrobe, by: { $0.category })
    }
    
    private var categories: [String] {
        groupedWardrobe.keys.sorted()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LiquidGlassBackgroundView()
                
                VStack(spacing: 0) {
                    // MARK: - EDITORIAL HEADER
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CLOSET")
                                .font(.system(size: 15, weight: .bold, design: .serif))
                                .tracking(3)
                                .foregroundColor(luxeGold)
                            Text("\(selectedItems.count) PIECES SELECTED")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.luxeBeige.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        Button(action: { dismiss() }) {
                            Text("DONE")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(2)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .foregroundColor(.black)
                                .liquidGlassGoldButton(cornerRadius: 12)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                    // MARK: - LUXE SEARCH BAR
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(luxeGold.opacity(0.8))
                        
                        TextField("", text: $searchText, prompt: Text("Search by subcategory...").foregroundColor(.gray))
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.04))
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.35), .white.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 15)

                    if isLoading {
                        Spacer()
                        ProgressView().tint(luxeGold)
                        Spacer()
                    } else if wardrobe.isEmpty {
                        emptyStateView(title: "EMPTY CLOSET", sub: "Import items into your closet first.")
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 25) {
                                ForEach(categories, id: \.self) { category in
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text(category.uppercased())
                                            .font(.system(size: 11, weight: .bold))
                                            .tracking(2)
                                            .foregroundColor(luxeBronze)
                                            .padding(.horizontal, 22)
                                        
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 14) {
                                                ForEach(groupedWardrobe[category] ?? []) { item in
                                                    wardrobeCard(item: item)
                                                }
                                            }
                                            .padding(.horizontal, 22)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 10)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
        }
        .onAppear { fetchUserClothes() }
    }
    
    // MARK: - COMPONENT: WARDROBE CARD
    @ViewBuilder
    private func wardrobeCard(item: WardrobeItem) -> some View {
        let isSelected = selectedItems.contains(item.id)
        
        Button(action: { toggleSelection(item: item) }) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    // Frosted card base
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                        )
                        .frame(width: 140, height: 180)
                    
                    KFImage(URL(string: item.imageURL))
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(
                                    isSelected ? AnyShapeStyle(Color.luxeGoldGradient) : AnyShapeStyle(
                                        LinearGradient(
                                            colors: [.white.opacity(0.35), Color.luxeEcru.opacity(0.15), .white.opacity(0.05)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    ),
                                    lineWidth: isSelected ? 2.5 : 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(luxeGold)
                            .background(Circle().fill(Color.black.opacity(0.7)))
                            .padding(8)
                    }
                }
                
                Text(item.subcategory.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(isSelected ? luxeGold : Color.luxeBeige.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private func toggleSelection(item: WardrobeItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    private func emptyStateView(title: String, sub: String) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "hanger")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.luxeGoldGradient)
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .serif))
                .tracking(2)
                .foregroundColor(luxeGold)
            Text(sub)
                .font(.caption)
                .foregroundColor(Color.luxeBeige.opacity(0.6))
            Spacer()
        }
        .padding(32)
        .liquidGlassCard(cornerRadius: 20)
        .padding(.horizontal, 24)
        .padding(.top, 40)
    }

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
                        imageURL: data["imageURL"] as? String ?? data["remoteURL"] as? String ?? "",
                        category: data["category"] as? String ?? "Other",
                        subcategory: data["subcategory"] as? String ?? data["subCategory"] as? String ?? "General"
                    )
                } ?? []
                
                isLoading = false
            }
    }
}
