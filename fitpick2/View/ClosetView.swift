//
//  ClosetView.swift
//  fitpick
//
//  Created by Bryan Gavino on 1/19/26.
//

import SwiftUI
import PhotosUI

struct ClosetView: View {
    @StateObject private var viewModel = ClosetViewModel()
    
    @State private var userPortrait: UIImage? = nil
    @State private var selectedItemIDs: Set<String> = []
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var itemToDelete: ClothingItem?
    @State private var showingDeleteAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // --- FIX START ---
                    // Added the missing 'tryOnMessage' argument
                    ClosetHeaderView(
                        tryOnImage: $viewModel.generatedTryOnImage,
                        tryOnMessage: $viewModel.tryOnMessage
                    )
                    // --- FIX END ---
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)

                ClosetActionButtons(
                    viewModel: viewModel,
                    selectedItemIDs: selectedItemIDs,
                    showCamera: $showCamera
                )

                InventoryList(
                    viewModel: viewModel,
                    selectedItemIDs: $selectedItemIDs,
                    itemToDelete: $itemToDelete,
                    showingDeleteAlert: $showingDeleteAlert
                )
            }
            .listStyle(.plain)
            .navigationTitle("Closet")
            .onAppear { viewModel.fetchUserGender() }
            .sheet(isPresented: $showCamera) {
                CameraPicker(selectedImage: $capturedImage)
            }
            .onChange(of: capturedImage) { _, newValue in
                if let image = newValue {
                    Task {
                        await viewModel.uploadAndCategorize(uiImage: image)
                        capturedImage = nil
                    }
                }
            }
            .alert("Delete Item?", isPresented: $showingDeleteAlert, presenting: itemToDelete) { item in
                Button("Delete", role: .destructive) { viewModel.deleteItem(item) }
            }
        }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TryOnSuggestion"))) { note in
                if let ids = note.userInfo?["ids"] as? [String] {
                    // Pre-select suggested items
                    selectedItemIDs = Set(ids)
                }
            }
    }
}

// MARK: - Sub-View: Action Buttons
struct ClosetActionButtons: View {
    // 1. Add ViewModel Reference
    @ObservedObject var viewModel: ClosetViewModel
    let selectedItemIDs: Set<String>
    @Binding var showCamera: Bool

    var body: some View {
        Section {
            HStack(spacing: 12) {
                // TRY ON BUTTON
                Button(action: {
                    // 2. Call the AI Generation Function
                    Task {
                        await viewModel.generateVirtualTryOn(selectedItemIDs: selectedItemIDs)
                    }
                }) {
                    Group {
                        if viewModel.isGeneratingTryOn {
                            ProgressView()
                                .tint(.purple)
                        } else {
                            let count = selectedItemIDs.count
                            Label(count > 0 ? "Try On (\(count))" : "Try On", systemImage: "sparkles")
                                .font(.subheadline.bold())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(selectedItemIDs.isEmpty ? Color.gray.opacity(0.1) : Color.purple.opacity(0.1))
                    .foregroundColor(selectedItemIDs.isEmpty ? .gray : .purple)
                    .cornerRadius(12)
                }
                .buttonStyle(BorderlessButtonStyle())
                // Disable if empty OR if currently generating
                .disabled(selectedItemIDs.isEmpty || viewModel.isGeneratingTryOn)

                // ADD CLOTHING BUTTON
                Button(action: { showCamera = true }) {
                    Group {
                        if viewModel.isUploading {
                            ProgressView()
                                .tint(.blue)
                        } else {
                            Label("Add Clothing", systemImage: "camera.fill")
                                .font(.subheadline.bold())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(12)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(viewModel.isUploading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
    }
}

// MARK: - Sub-View: Inventory List (Unchanged)
struct InventoryList: View {
    @ObservedObject var viewModel: ClosetViewModel
    @Binding var selectedItemIDs: Set<String>
    @Binding var itemToDelete: ClothingItem?
    @Binding var showingDeleteAlert: Bool

    var body: some View {
        ForEach(ClothingCategory.allCases) { category in
            CategoryInventoryRow(
                category: category,
                viewModel: viewModel,
                selectedItemIDs: $selectedItemIDs,
                itemToDelete: $itemToDelete,
                showingDeleteAlert: $showingDeleteAlert
            )
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
        }
    }
}

// MARK: - Sub-View: Category Row (Unchanged)
struct CategoryInventoryRow: View {
    let category: ClothingCategory
    @ObservedObject var viewModel: ClosetViewModel
    @Binding var selectedItemIDs: Set<String>
    @Binding var itemToDelete: ClothingItem?
    @Binding var showingDeleteAlert: Bool
    
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
            }) {
                HStack {
                    Label(category.rawValue, systemImage: category.icon)
                        .font(.headline).foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.vertical, 15).padding(.horizontal, 20)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: 25) {
                    let itemsInCat = viewModel.clothingItems.filter { $0.category == category }
                    let subCats = Array(Set(itemsInCat.map { $0.subCategory })).sorted()
                    
                    if subCats.isEmpty {
                        Text("No items yet").font(.caption).foregroundColor(.gray).padding(.horizontal, 20)
                    } else {
                        ForEach(subCats, id: \.self) { subName in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(subName).font(.caption).bold().foregroundColor(.secondary).padding(.horizontal, 20)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        let filtered = itemsInCat.filter { $0.subCategory == subName }
                                        ForEach(filtered) { item in
                                            inventoryItem(item)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 10)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            Divider().padding(.horizontal, 20)
        }
    }

    private func inventoryItem(_ item: ClothingItem) -> some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 100, height: 130)
                
                AsyncImage(url: URL(string: item.remoteURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 130)
                            .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                    case .failure:
                        VStack(spacing: 4) {
                            Image(systemName: "wifi.exclamationmark").font(.caption)
                            Text("Retry").font(.system(size: 8))
                        }.foregroundColor(.gray)
                    case .empty:
                        ProgressView().tint(.blue).scaleEffect(0.8)
                    @unknown default: EmptyView()
                    }
                }
            }
            .frame(width: 100, height: 130)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedItemIDs.contains(item.id) ? Color.blue : Color.clear, lineWidth: 3)
            )
            .onTapGesture {
                if selectedItemIDs.contains(item.id) {
                    selectedItemIDs.remove(item.id)
                } else {
                    selectedItemIDs.insert(item.id)
                }
            }

            Button {
                itemToDelete = item
                showingDeleteAlert = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.red)
                    .background(Circle().fill(Color.white))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
            .offset(x: 8, y: -8)
        }
        .padding([.top, .trailing], 8)
    }
}
