//
//  ContentView.swift
//  fitpick
//
//  Created by Bry on 1/19/26.
//

import SwiftUI
import PhotosUI

struct ClosetView: View {
    @StateObject private var viewModel = ClosetViewModel()
    
    // User Portrait State
    @State private var userPortrait: UIImage? = nil
    @State private var selectedPortraitItem: PhotosPickerItem? = nil
    
    // UI Interaction States
    @State private var selectedItemID: UUID? = nil
    @State private var showCamera = false  // EXCLUSIVELY for Add Clothing
    @State private var capturedImage: UIImage?
    @State private var itemToDelete: ClothingItem?
    @State private var showingDeleteAlert = false
    
    // Selection States
    @State private var showingCategorySelection = false
    @State private var selectedCategory: ClothingCategory?
    @State private var showingSubCategorySelection = false

    var body: some View {
        NavigationStack {
            List {
                // SECTION 1: Portrait Header
                Section {
                    PhotosPicker(selection: $selectedPortraitItem, matching: .images) {
                        ClosetHeaderView(portraitImage: userPortrait != nil ? Image(uiImage: userPortrait!) : nil)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)

                                // SECTION 2: Action Buttons
                                Section {
                                    HStack(spacing: 12) {
                                        // TRY ON BUTTON
                                        Button(action: {
                                            if let selectedID = selectedItemID {
                                                print("DEBUG: Logic Triggered for \(selectedID)")
                                            } else {
                                                print("DEBUG: Select an item first")
                                            }
                                        }) {
                                            Label("Try On", systemImage: "sparkles")
                                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                                .background(Color.purple.opacity(0.1))
                                                .foregroundColor(.purple)
                                                .cornerRadius(12)
                                        }
                                        .buttonStyle(PlainButtonStyle()) // FIX: Prevents List row conflict
                                        
                                        // ADD CLOTHING BUTTON
                                        Button(action: {
                                            self.showCamera = true
                                        }) {
                                            if viewModel.isUploading {
                                                ProgressView()
                                            } else {
                                                Label("Add Clothing", systemImage: "camera.fill")
                                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                                    .background(Color.blue.opacity(0.1))
                                                    .foregroundColor(.blue)
                                                    .cornerRadius(12)
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle()) // FIX: Prevents List row conflict
                                        .disabled(viewModel.isUploading)
                                    }
                                }
                                .listRowBackground(Color.clear) // Cleaner UI
                                .listRowSeparator(.hidden)

                // SECTION 3: Inventory
                ForEach(ClothingCategory.allCases) { category in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(category.rawValue, systemImage: category.icon)
                            .font(.subheadline).bold().padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                let filtered = viewModel.clothingItems.filter { $0.category == category }
                                ForEach(filtered) { item in
                                    VStack(alignment: .center, spacing: 4) {
                                        ZStack(alignment: .topTrailing) {
                                            item.image.resizable().scaledToFit().frame(width: 100, height: 130)
                                                .background(Color.secondary.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12))
                                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedItemID == item.id ? Color.blue : Color.clear, lineWidth: 3))
                                                .onTapGesture { selectedItemID = item.id }

                                            Button { itemToDelete = item; showingDeleteAlert = true } label: {
                                                Image(systemName: "xmark.circle.fill").foregroundColor(.red).background(Circle().fill(Color.white))
                                            }.offset(x: 5, y: -5)
                                        }
                                        Text(item.subCategory).font(.system(size: 10)).foregroundColor(.secondary)
                                    }
                                }
                            }.padding(.horizontal).padding(.top, 10)
                        }
                    }
                }
            }
            .navigationTitle("Closet")
            .onAppear { viewModel.fetchUserGender() }
            // CAMERA TRIGGERED ONLY BY showCamera
            .sheet(isPresented: $showCamera) {
                CameraPicker(selectedImage: $capturedImage)
            }
            .onChange(of: capturedImage) { _, val in if val != nil { showingCategorySelection = true } }
            .confirmationDialog("Category", isPresented: $showingCategorySelection) {
                ForEach(ClothingCategory.allCases) { cat in
                    Button(cat.rawValue) {
                        selectedCategory = cat
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showingSubCategorySelection = true }
                    }
                }
            }
            .confirmationDialog("Style", isPresented: $showingSubCategorySelection, presenting: selectedCategory) { cat in
                let subCats = cat.subCategories(for: viewModel.userGender)
                ForEach(subCats, id: \.self) { sub in
                    Button(sub) {
                        if let img = capturedImage { viewModel.uploadClothing(uiImage: img, category: cat, subCategory: sub) }
                        capturedImage = nil
                    }
                }
                Button("Cancel", role: .cancel) { capturedImage = nil }
            }
        }
    }
    
    private func handlePortraitSelection() {
        Task {
            if let data = try? await selectedPortraitItem?.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                await MainActor.run { self.userPortrait = uiImage }
            }
        }
    }
}
