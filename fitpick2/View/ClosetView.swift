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
    
    // UI & Portrait State
    @State private var userPortrait: UIImage? = nil
    @State private var selectedItemID: UUID? = nil
    
    // Camera & Upload State
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    
    // Dialog & Alert State
    @State private var showingCategorySelection = false
    @State private var selectedCategory: ClothingCategory?
    @State private var showingSubCategorySelection = false
    @State private var itemToDelete: ClothingItem?
    @State private var showingDeleteAlert = false

    var body: some View {
        NavigationStack {
            List {
                // Header
                Section {
                    ClosetHeaderView(portraitImage: userPortrait != nil ? Image(uiImage: userPortrait!) : nil)
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)

                // Action Buttons
                ClosetActionButtons(
                    selectedItemID: selectedItemID,
                    isUploading: viewModel.isUploading,
                    showCamera: $showCamera
                )

                // Collapsible Inventory List
                InventoryList(
                    viewModel: viewModel,
                    selectedItemID: $selectedItemID,
                    itemToDelete: $itemToDelete,
                    showingDeleteAlert: $showingDeleteAlert
                )
            }
            .listStyle(.plain)
            .navigationTitle("Closet")
            .onAppear {
                viewModel.fetchUserGender()
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker(selectedImage: $capturedImage)
            }
            .onChange(of: capturedImage) { _, newValue in
                if newValue != nil { showingCategorySelection = true }
            }
            .confirmationDialog("Category", isPresented: $showingCategorySelection) {
                categoryDialogButtons
            }
            .confirmationDialog("Style", isPresented: $showingSubCategorySelection) {
                subCategoryDialogButtons
            }
            .alert("Delete Item?", isPresented: $showingDeleteAlert, presenting: itemToDelete) { item in
                Button("Delete", role: .destructive) { viewModel.deleteItem(item) }
            }
        }
    }

    @ViewBuilder
    private var categoryDialogButtons: some View {
        ForEach(ClothingCategory.allCases) { category in
            Button(category.rawValue) {
                selectedCategory = category
                showingSubCategorySelection = true
            }
        }
    }

    @ViewBuilder
    private var subCategoryDialogButtons: some View {
        if let category = selectedCategory {
            ForEach(category.subCategories(for: viewModel.userGender), id: \.self) { subCat in
                Button(subCat) {
                    if let img = capturedImage {
                        viewModel.uploadClothing(uiImage: img, category: category, subCategory: subCat)
                        capturedImage = nil
                    }
                }
            }
        }
    }
}

// MARK: - Sub-View: Action Buttons
struct ClosetActionButtons: View {
    let selectedItemID: UUID?
    let isUploading: Bool
    @Binding var showCamera: Bool

    var body: some View {
        Section {
            HStack(spacing: 12) {
                Button(action: { print("Try On") }) {
                    Label("Try On", systemImage: "sparkles")
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.purple.opacity(0.1))
                        .foregroundColor(.purple)
                        .cornerRadius(12)
                }
                .buttonStyle(BorderlessButtonStyle())

                Button(action: { showCamera = true }) {
                    if isUploading {
                        ProgressView()
                    } else {
                        Label("Add Clothing", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(isUploading)
            }
        }
        .listRowSeparator(.hidden)
    }
}

// MARK: - Sub-View: Inventory List
struct InventoryList: View {
    @ObservedObject var viewModel: ClosetViewModel
    @Binding var selectedItemID: UUID?
    @Binding var itemToDelete: ClothingItem?
    @Binding var showingDeleteAlert: Bool

    var body: some View {
        ForEach(ClothingCategory.allCases) { category in
            CategoryInventoryRow(
                category: category,
                viewModel: viewModel,
                selectedItemID: $selectedItemID,
                itemToDelete: $itemToDelete,
                showingDeleteAlert: $showingDeleteAlert
            )
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
        }
    }
}

// MARK: - Sub-View: Row Layout (Reverted to Stable Logic)
struct CategoryInventoryRow: View {
    let category: ClothingCategory
    @ObservedObject var viewModel: ClosetViewModel
    @Binding var selectedItemID: UUID?
    @Binding var itemToDelete: ClothingItem?
    @Binding var showingDeleteAlert: Bool
    
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Toggle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Label(category.rawValue, systemImage: category.icon)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Down when collapsed, Right when expanded
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : 90))
                }
                .padding(.vertical, 15)
                .padding(.horizontal, 20)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: 25) {
                    let subCats = category.subCategories(for: viewModel.userGender)
                    
                    ForEach(subCats, id: \.self) { subName in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(subName)
                                .font(.caption).bold().foregroundColor(.secondary).padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    let filtered = viewModel.clothingItems.filter {
                                        $0.category == category && $0.subCategory == subName
                                    }
                                    
                                    if filtered.isEmpty {
                                        Text("No \(subName)").font(.system(size: 10)).foregroundColor(.gray)
                                            .frame(width: 100, height: 130).background(Color.secondary.opacity(0.05)).cornerRadius(12)
                                    } else {
                                        ForEach(filtered) { item in
                                            inventoryItem(item)
                                        }
                                    }
                                }.padding(.horizontal, 20)
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
                .transition(.opacity)
            }
            
            Divider().padding(.horizontal, 20)
        }
    }

    private func inventoryItem(_ item: ClothingItem) -> some View {
        ZStack(alignment: .topTrailing) {
            item.image.resizable().scaledToFit().frame(width: 100, height: 130)
                .background(Color.secondary.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedItemID == item.id ? Color.blue : Color.clear, lineWidth: 3))
                .onTapGesture { selectedItemID = item.id }

            Button { itemToDelete = item; showingDeleteAlert = true } label: {
                Image(systemName: "xmark.circle.fill").foregroundColor(.red).background(Circle().fill(Color.white))
            }.offset(x: 5, y: -5)
        }
    }
}
