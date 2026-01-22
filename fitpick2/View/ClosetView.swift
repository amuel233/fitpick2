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
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var itemToDelete: ClothingItem?
    @State private var showingDeleteAlert = false
    
    // Sequential Selection States for Add Clothing
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

                // SECTION 2: Action Buttons (Try On & Add)
                Section {
                    HStack(spacing: 12) {
                        Button(action: { /* Trigger AI Try-On Logic */ }) {
                            Label("Try On", systemImage: "sparkles")
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color.purple.opacity(0.1)).cornerRadius(12)
                        }
                        
                        Button(action: { showCamera = true }) {
                            if viewModel.isUploading {
                                ProgressView()
                            } else {
                                Label("Add Clothing", systemImage: "camera.fill")
                            }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .disabled(viewModel.isUploading)
                    }
                }
                .listRowSeparator(.hidden)

                // SECTION 3: Categorized Inventory with Sub-Category Labels
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
                                                .onTapGesture { selectedItemID = item.id }

                                            // Delete Button
                                            Button {
                                                itemToDelete = item
                                                showingDeleteAlert = true
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.red)
                                                    .background(Circle().fill(Color.white))
                                            }
                                            .offset(x: 5, y: -5)
                                        }
                                        
                                        // Display Sub-category Label
                                        Text(item.subCategory)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 10)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Closet")
            // Camera Sheet
            .sheet(isPresented: $showCamera) {
                CameraPicker(selectedImage: $capturedImage)
            }
            // Step 1: Main Category Selection
            .onChange(of: capturedImage) { _, newValue in
                if newValue != nil { showingCategorySelection = true }
            }
            .confirmationDialog("Select Main Category", isPresented: $showingCategorySelection) {
                ForEach(ClothingCategory.allCases) { category in
                    Button(category.rawValue) {
                        selectedCategory = category
                        showingSubCategorySelection = true
                    }
                }
            }
            // Step 2: Gender-Based Sub-Category Selection
            .confirmationDialog("Select Style", isPresented: $showingSubCategorySelection) {
                if let category = selectedCategory {
                    ForEach(category.subCategories(for: viewModel.userGender), id: \.self) { subCat in
                        Button(subCat) {
                            if let img = capturedImage {
                                viewModel.uploadClothing(uiImage: img, category: category, subCategory: subCat)
                                capturedImage = nil // Reset after starting upload
                            }
                        }
                    }
                }
            }
            // Portrait and Deletion Handlers
            .onChange(of: selectedPortraitItem) { _, _ in handlePortraitSelection() }
            .alert("Delete Item?", isPresented: $showingDeleteAlert, presenting: itemToDelete) { item in
                Button("Delete", role: .destructive) { viewModel.deleteItem(item) }
            }
        }
    }
    
    // Private Helper for Portrait (MVVM: This should eventually move to ViewModel)
    private func handlePortraitSelection() {
        Task {
            if let data = try? await selectedPortraitItem?.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run { self.userPortrait = uiImage }
            }
        }
    }
}
