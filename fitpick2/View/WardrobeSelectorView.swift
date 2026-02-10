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
}

struct WardrobeSelectorView: View {
    @Binding var selectedItems: Set<String>
    @State private var wardrobe: [WardrobeItem] = []
    @State private var isLoading = true
    @Environment(\.dismiss) var dismiss
    
    // Theme Colors
    let fitPickGold = Color("fitPickGold")
    let fitPickWhite = Color(red: 245/255, green: 245/255, blue: 247/255)
    let fitPickText = Color(red: 26/255, green: 26/255, blue: 27/255)

    var body: some View {
        NavigationStack {
            ZStack {
                fitPickWhite.ignoresSafeArea()
                
                if isLoading {
                    ProgressView().tint(fitPickGold)
                } else if wardrobe.isEmpty {
                    VStack(spacing: 15) {
                        Image(systemName: "tshirt")
                            .font(.system(size: 50))
                            .foregroundColor(fitPickGold.opacity(0.5))
                        Text("Your closet is empty")
                            .font(.headline)
                        Text("Upload clothes to your wardrobe first to tag them.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 15)], spacing: 15) {
                            ForEach(wardrobe) { item in
                                wardrobeItemCard(item: item)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Select Items")
            .navigationBarTitleDisplayMode(.inline)
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

    @ViewBuilder
    private func wardrobeItemCard(item: WardrobeItem) -> some View {
        // We check against the item ID (Document ID)
        let isSelected = selectedItems.contains(item.id)
        
        VStack {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: item.imageURL)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.2))
                }
                .frame(width: 110, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? fitPickGold : Color.clear, lineWidth: 3)
                )
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(fitPickGold)
                        .background(Circle().fill(Color.white))
                        .offset(x: 5, y: -5)
                }
            }
            
            Text(item.category)
                .font(.caption2)
                .foregroundColor(fitPickText.opacity(0.7))
        }
        .onTapGesture {
            // Toggle the Document ID in the set
            if isSelected {
                selectedItems.remove(item.id)
            } else {
                selectedItems.insert(item.id)
            }
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
                    print("Error fetching clothes: \(error.localizedDescription)")
                }
                
                self.wardrobe = snap?.documents.compactMap { doc in
                    let data = doc.data()
                    return WardrobeItem(
                        id: doc.documentID, // Storing the Document ID
                        imageURL: data["imageURL"] as? String ?? "",
                        category: data["category"] as? String ?? "Item"
                    )
                } ?? []
                
                isLoading = false
            }
    }
}
