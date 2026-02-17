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
    let fitPickGold = Color(red: 0.75, green: 0.60, blue: 0.22)
    let editorBlack = Color(red: 10/255, green: 10/255, blue: 10/255)
    let surfaceDark = Color(white: 0.08)

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
                editorBlack.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - EDITORIAL HEADER
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CLOSET")
                                .font(.system(size: 14, weight: .black))
                                .tracking(4)
                                .foregroundColor(fitPickGold)
                            Text("\(selectedItems.count) PIECES SELECTED")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        
                        Spacer()
                        
                        Button(action: { dismiss() }) {
                            Text("DONE")
                                .font(.system(size: 11, weight: .black))
                                .tracking(2)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(fitPickGold)
                                .foregroundColor(.black)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, 25)
                    .padding(.bottom, 20)

                    // MARK: - LUXE SEARCH BAR
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(fitPickGold.opacity(0.6))
                        
                        TextField("", text: $searchText, prompt: Text("Search by subcategory...").foregroundColor(.white.opacity(0.2)))
                            .font(.system(size: 14, design: .serif)).italic()
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 12)
                    .background(surfaceDark)
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 15)

                    if isLoading {
                        Spacer()
                        ProgressView().tint(fitPickGold)
                        Spacer()
                    } else if wardrobe.isEmpty {
                        emptyStateView(title: "EMPTY CLOSET", sub: "Import items into your closet first.")
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 30) {
                                ForEach(categories, id: \.self) { category in
                                    VStack(alignment: .leading, spacing: 15) {
                                        Text(category.uppercased())
                                            .font(.system(size: 10, weight: .black))
                                            .tracking(3)
                                            .foregroundColor(fitPickGold)
                                            .padding(.horizontal, 25)
                                        
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 15) {
                                                ForEach(groupedWardrobe[category] ?? []) { item in
                                                    wardrobeCard(item: item)
                                                }
                                            }
                                            .padding(.horizontal, 25)
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
                    KFImage(URL(string: item.imageURL))
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 180)
                        .background(surfaceDark)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? fitPickGold : Color.white.opacity(0.05), lineWidth: isSelected ? 2 : 1)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(fitPickGold)
                            .background(Circle().fill(.black))
                            .padding(8)
                    }
                }
                
                Text(item.subcategory.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundColor(isSelected ? fitPickGold : .white.opacity(0.6))
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
        VStack(spacing: 15) {
            Spacer()
            Image(systemName: "tshirt")
                .font(.system(size: 40, weight: .thin))
                .foregroundColor(fitPickGold.opacity(0.3))
            Text(title)
                .font(.system(size: 12, weight: .black)).tracking(2)
                .foregroundColor(fitPickGold)
            Text(sub)
                .font(.system(size: 13, design: .serif)).italic()
                .foregroundColor(.white.opacity(0.4))
            Spacer()
        }
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
                        imageURL: data["imageURL"] as? String ?? "",
                        category: data["category"] as? String ?? "Other",
                        subcategory: data["subcategory"] as? String ?? "General"
                    )
                } ?? []
                
                isLoading = false
            }
    }
}
