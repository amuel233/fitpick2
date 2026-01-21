//
//  ContentView.swift
//  fitpick
//
//  Created by Bry on 1/19/26.
//

import SwiftUI
import PhotosUI

struct ClosetView: View {
    @State private var clothingItems: [ClothingItem] = []
    @State private var userPortrait: UIImage? = nil
    @State private var selectedItemID: UUID? = nil
    
    @State private var showingDeleteAlert = false
    @State private var itemToDelete: ClothingItem?
    
    @State private var selectedClothingItem: PhotosPickerItem? = nil
    @State private var selectedPortraitItem: PhotosPickerItem? = nil
    @State private var activeCategory: ClothingCategory?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    PhotosPicker(selection: $selectedPortraitItem, matching: .images) {
                        ClosetHeaderView(
                            portraitImage: userPortrait != nil ? Image(uiImage: userPortrait!) : nil
                        )
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)

                ForEach(ClothingCategory.allCases) { category in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(category.rawValue, systemImage: category.icon)
                            .font(.subheadline).bold()
                            .padding(.horizontal)
                        
                        HStack(alignment: .center, spacing: 0) {
                            // 1. Scrollable Area
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    let filtered = clothingItems.filter { $0.category == category }
                                    
                                    ForEach(filtered) { item in
                                        ZStack(alignment: .topTrailing) {
                                            item.image
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 100, height: 130)
                                                .background(Color.secondary.opacity(0.1))
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(selectedItemID == item.id ? Color.blue : Color.clear, lineWidth: 3)
                                                )
                                                .onTapGesture {
                                                    withAnimation {
                                                        selectedItemID = (selectedItemID == item.id) ? nil : item.id
                                                    }
                                                }

                                            Button {
                                                itemToDelete = item
                                                showingDeleteAlert = true
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.title3)
                                                    .foregroundColor(.red)
                                                    .background(Circle().fill(Color.white))
                                                    .shadow(radius: 2)
                                            }
                                            .offset(x: 5, y: -5)
                                        }
                                    }
                                }
                                .padding(.leading)
                                .padding(.top, 10)
                                .padding(.bottom, 5)
                            }
                            
                            // 2. FIXED PERSISTENT ADD BUTTON
                            // By using a plain button style and setting activeCategory
                            // inside the label's tap area, we ensure the whole button works.
                            PhotosPicker(selection: $selectedClothingItem, matching: .images) {
                                VStack(spacing: 4) {
                                    Image(systemName: "plus.square.fill.on.square.fill")
                                        .font(.title2)
                                    Text("Add")
                                        .font(.caption2).bold()
                                }
                                .foregroundColor(.blue)
                                .frame(width: 70, height: 130)
                                .background(Color.blue.opacity(0.08))
                                .contentShape(Rectangle()) // Makes the entire frame tappable
                            }
                            .buttonStyle(.plain) // Prevents default list-row behavior
                            .simultaneousGesture(TapGesture().onEnded {
                                // This ensures the category is set no matter where on the button you tap
                                self.activeCategory = category
                            })
                            .padding(.trailing)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Closet")
            .onChange(of: selectedClothingItem) { _, _ in handleClothingSelection() }
            .onChange(of: selectedPortraitItem) { _, _ in handlePortraitSelection() }
            .alert("Delete Item?", isPresented: $showingDeleteAlert, presenting: itemToDelete) { item in
                Button("Delete", role: .destructive) { deleteItem(item) }
                Button("Cancel", role: .cancel) { itemToDelete = nil }
            } message: { _ in
                Text("Are you sure you want to remove this item?")
            }
        }
    }
}

// MARK: - Logic (Corrected loadTransferable)
private extension ClosetView {
    func handleClothingSelection() {
        Task {
            // Using loadTransferable for proper data handling
            if let data = try? await selectedClothingItem?.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data),
               let category = activeCategory {
                
                await MainActor.run {
                    let newItem = ClothingItem(image: Image(uiImage: uiImage), uiImage: uiImage, category: category)
                    withAnimation {
                        clothingItems.append(newItem)
                    }
                    selectedClothingItem = nil
                    activeCategory = nil
                }
            }
        }
    }

    func handlePortraitSelection() {
        Task {
            if let data = try? await selectedPortraitItem?.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run { self.userPortrait = uiImage }
            }
        }
    }
    
    func deleteItem(_ item: ClothingItem) {
        withAnimation {
            // Remove exactly by unique ID
            clothingItems.removeAll { $0.id == item.id }
            if selectedItemID == item.id {
                selectedItemID = nil
            }
            itemToDelete = nil
        }
    }
}
