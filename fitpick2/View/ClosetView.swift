//
//  ClosetView.swift
//  fitpick
//
//  Created by Bryan Gavino on 1/19/26.
//

import SwiftUI
import PhotosUI
import Kingfisher

struct ClosetView: View {
    // MARK: - Properties
    @StateObject private var viewModel = ClosetViewModel()
    
    // Grid Filter State
    @State private var selectedCategoryFilter: ClothingCategory? = nil
    
    // Selection & State
    @State private var selectedItemIDs: Set<String> = []
    
    // Manual Add (Gallery)
    @State private var photoSelection: PhotosPickerItem? = nil
    @State private var showManualAddSheet = false
    @State private var imageForManualAdd: UIImage?
    
    // Smart Add (Camera/LiDAR)
    @State private var showSmartScan = false
    
    // Zoom & Delete
    @State private var zoomedItem: ClothingItem? = nil
    @State private var itemToDelete: ClothingItem?
    @State private var showingDeleteAlert = false
    
    // MARK: - DRAWER GESTURE STATE
    private let screenHeight = UIScreen.main.bounds.height
    
    // Snap Points
    private var maxOpenOffset: CGFloat { screenHeight * 0.12 }      // Top (Full Closet)
    private var midOffset: CGFloat { screenHeight * 0.47 }          // Mid (Half/Half - Shows Full Header Image)

    // State: Initialize to MID Offset
    @State private var currentDrawerOffset: CGFloat = UIScreen.main.bounds.height * 0.47
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                
                // MARK: LAYER 1 - Background (Virtual Mirror)
                VStack {
                    ClosetHeaderView(
                        tryOnImage: $viewModel.generatedTryOnImage,
                        tryOnMessage: $viewModel.tryOnMessage,
                        onSave: { Task { await viewModel.saveCurrentLook() } },
                        isSaving: viewModel.isSavingTryOn,
                        isSaved: viewModel.tryOnSavedSuccess
                    )
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 60) // Push down from top edge
                }
                .background(Color(uiColor: .systemGroupedBackground))
                
                // MARK: LAYER 2 - Draggable Wardrobe Drawer
                VStack(spacing: 0) {
                    // 1. Grabber Handle
                    ZStack {
                        Color.white // Touch target
                        Capsule()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 5)
                            .padding(.vertical, 12)
                    }
                    .frame(height: 30)
                    .gesture(
                        DragGesture()
                            .onChanged(handleDragChanged)
                            .onEnded(handleDragEnded)
                    )
                    
                    // 2. Content Container
                    VStack(spacing: 0) {
                        ClosetActionButtons(
                            viewModel: viewModel,
                            selectedItemIDs: selectedItemIDs,
                            showSmartScan: $showSmartScan,
                            photoSelection: $photoSelection,
                            onTryOn: {
                                // Reset Drawer to Mid when Try On is clicked
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    currentDrawerOffset = midOffset
                                }
                            }
                        )
                        .padding(.bottom, 10)
                        
                        ClosetFilterView(selectedCategory: $selectedCategoryFilter)
                            .padding(.bottom, 10)
                        
                        ScrollView {
                            InventoryGrid(
                                viewModel: viewModel,
                                selectedItemIDs: $selectedItemIDs,
                                itemToDelete: $itemToDelete,
                                showingDeleteAlert: $showingDeleteAlert,
                                selectedCategory: selectedCategoryFilter,
                                zoomedItem: $zoomedItem
                            )
                            // Massive padding to ensure Delete button clears menus
                            .padding(.bottom, 250)
                        }
                        // Disable scroll if drawer is closed to avoid conflict
                        .scrollDisabled(currentDrawerOffset > maxOpenOffset + 50)
                    }
                }
                .background(Color.white)
                .clipShape(RoundedCorner(radius: 30, corners: [.topLeft, .topRight]))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                .frame(height: screenHeight * 0.90)
                .offset(y: currentDrawerOffset + dragOffset)
                .offset(y: 30) // Safe area correction
                
                // MARK: LAYER 3 - Zoom Overlay
                if let item = zoomedItem {
                    ZoomOverlayView(
                        item: item,
                        onDismiss: { withAnimation(.easeInOut) { zoomedItem = nil } },
                        onSaveSize: { newSize in
                            viewModel.updateItemSize(item, newSize: newSize)
                            var updated = item; updated.size = newSize; zoomedItem = updated
                        }
                    )
                    .zIndex(2)
                }
            }
            .navigationTitle("Closet")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { viewModel.fetchUserGender() }
            
            // MARK: - Sheets
            
            // 1. Smart Scan (Camera/LiDAR) -> No image param needed
            .sheet(isPresented: $showSmartScan) {
                SmartAddItemSheet(viewModel: viewModel)
            }
            
            // 2. Manual Add (Gallery) -> Requires image param
            .onChange(of: photoSelection) { _, val in
                Task {
                    if let d = try? await val?.loadTransferable(type: Data.self), let u = UIImage(data: d) {
                        await MainActor.run {
                            imageForManualAdd = u
                            showManualAddSheet = true
                            photoSelection = nil
                        }
                    }
                }
            }
            .sheet(isPresented: $showManualAddSheet) {
                if let img = imageForManualAdd {
                    AddItemSheet(image: img, viewModel: viewModel)
                } else {
                    Text("Error loading image")
                }
            }
            
            // 3. Delete Alert
            .alert("Delete?", isPresented: $showingDeleteAlert, presenting: itemToDelete) { i in
                Button("Delete", role: .destructive) { viewModel.deleteItem(i) }
            }
            
            // 4. Notifications
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TryOnSuggestion"))) { note in
                if let ids = note.userInfo?["ids"] as? [String] { selectedItemIDs = Set(ids) }
            }
        }
    }
    
    // MARK: - Gesture Logic (Refactored to fix compiler error)
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        let newOffset = currentDrawerOffset + value.translation.height
        // Drag Limits: Allow drag UP to Top, but restrict drag DOWN past Mid (+20 buffer)
        if newOffset > maxOpenOffset - 50 && newOffset < midOffset + 20 {
            dragOffset = value.translation.height
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        let predictedEnd = currentDrawerOffset + value.translation.height + (value.predictedEndLocation.y - value.location.y)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            // Snap Logic: Only snap to Top or Mid
            let distanceToTop = abs(predictedEnd - maxOpenOffset)
            let distanceToMid = abs(predictedEnd - midOffset)
            
            if distanceToTop < distanceToMid {
                currentDrawerOffset = maxOpenOffset
            } else {
                currentDrawerOffset = midOffset
            }
            dragOffset = 0
        }
    }
}

// MARK: - Subviews & Helpers

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct ClosetFilterView: View {
    @Binding var selectedCategory: ClothingCategory?
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChip(title: "All", isSelected: selectedCategory == nil) { withAnimation { selectedCategory = nil } }
                ForEach(ClothingCategory.allCases, id: \.self) { cat in
                    FilterChip(title: cat.rawValue, isSelected: selectedCategory == cat) { withAnimation { selectedCategory = cat } }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct FilterChip: View {
    let title: String; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(.medium)).padding(.horizontal, 16).padding(.vertical, 8)
                .background(isSelected ? Color.black : Color.white).foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20).shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.2), lineWidth: isSelected ? 0 : 1))
        }
    }
}

struct InventoryGrid: View {
    @ObservedObject var viewModel: ClosetViewModel
    @Binding var selectedItemIDs: Set<String>
    @Binding var itemToDelete: ClothingItem?
    @Binding var showingDeleteAlert: Bool
    var selectedCategory: ClothingCategory?
    @Binding var zoomedItem: ClothingItem?
    
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            let items = viewModel.clothingItems.filter { selectedCategory == nil ? true : $0.category == selectedCategory }
            if items.isEmpty { ContentUnavailableView("No Items", systemImage: "hanger").padding(.top, 50) }
            else {
                ForEach(items) { item in
                    InventoryItemCard(
                        item: item, isSelected: selectedItemIDs.contains(item.id),
                        onTap: { if selectedItemIDs.contains(item.id) { selectedItemIDs.remove(item.id) } else { selectedItemIDs.insert(item.id) } },
                        onDelete: { itemToDelete = item; showingDeleteAlert = true },
                        onLongPress: { let g = UIImpactFeedbackGenerator(style: .medium); g.impactOccurred(); withAnimation { zoomedItem = item } }
                    )
                }
            }
        }.padding(.horizontal, 16)
    }
}

struct InventoryItemCard: View {
    let item: ClothingItem; let isSelected: Bool; let onTap: () -> Void; let onDelete: () -> Void; let onLongPress: () -> Void
    var body: some View {
        ZStack(alignment: .topTrailing) {
            KFImage(URL(string: item.remoteURL)).placeholder { Color.gray.opacity(0.1) }
                .cacheOriginalImage().resizable().scaledToFill().frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 16)).contentShape(Rectangle())
                .onTapGesture(perform: onTap).onLongPressGesture(perform: onLongPress)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3))
            
            if isSelected { Image(systemName: "checkmark.circle.fill").font(.title3).foregroundColor(.blue).background(Circle().fill(.white)).padding(4) }
            if !item.size.isEmpty { Text(item.size).font(.caption2.bold()).padding(4).background(.ultraThinMaterial).clipShape(Capsule()).padding([.top, .leading], 4).frame(maxWidth: .infinity, alignment: .topLeading) }
            
            if !isSelected {
                Button(action: onDelete) {
                    Image(systemName: "xmark").font(.caption).foregroundColor(.white).padding(6).background(Color.black.opacity(0.4)).clipShape(Circle())
                }.padding(6).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
    }
}

struct ZoomOverlayView: View {
    let item: ClothingItem; let onDismiss: () -> Void; let onSaveSize: (String) -> Void
    @State private var isEditing = false; @State private var editedSize: String = ""
    var body: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea().onTapGesture(perform: onDismiss)
            VStack(spacing: 20) {
                KFImage(URL(string: item.remoteURL)).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 12)).padding()
                VStack {
                    Text(item.subCategory).font(.title2.bold()).foregroundColor(.white)
                    HStack {
                        Text(item.size.isEmpty ? "No Size" : "Size: \(item.size)").font(.headline).foregroundColor(.gray)
                        Button(action: { editedSize = item.size; isEditing = true }) { Image(systemName: "pencil.circle.fill").font(.title3).foregroundColor(.blue).background(Circle().fill(.white)) }
                    }
                }
            }
            VStack { HStack { Spacer(); Button(action: onDismiss) { Image(systemName: "xmark.circle.fill").font(.largeTitle).foregroundColor(.white).padding() } }; Spacer() }
        }
        .alert("Edit Size", isPresented: $isEditing) { TextField("Size", text: $editedSize); Button("Save") { onSaveSize(editedSize) }; Button("Cancel", role: .cancel) {} }
    }
}

// MARK: - Action Buttons
struct ClosetActionButtons: View {
    @ObservedObject var viewModel: ClosetViewModel
    let selectedItemIDs: Set<String>
    
    // Bindings
    @Binding var showSmartScan: Bool
    @Binding var photoSelection: PhotosPickerItem?
    
    // Actions
    var onTryOn: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 1. Try On Button
            Button(action: {
                onTryOn()
                Task { await viewModel.generateVirtualTryOn(selectedItemIDs: selectedItemIDs) }
            }) {
                Group {
                    if viewModel.isGeneratingTryOn { HStack { ProgressView().tint(.white); Text("Styling...") } }
                    else { HStack { Image(systemName: "sparkles"); Text(selectedItemIDs.count > 0 ? "Try On (\(selectedItemIDs.count))" : "Try On") }.bold() }
                }
                .font(.subheadline)
                .frame(height: 50).frame(maxWidth: .infinity)
                .background(LinearGradient(colors: selectedItemIDs.isEmpty ? [.gray] : [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .foregroundColor(.white).cornerRadius(16)
            }.disabled(selectedItemIDs.isEmpty || viewModel.isGeneratingTryOn)

            // 2. Camera Button (Smart LiDAR Scan)
            Button(action: { showSmartScan = true }) {
                Image(systemName: "camera.fill").font(.title3).frame(width: 50, height: 50).background(Color.white).foregroundColor(.blue).cornerRadius(16).shadow(radius: 2)
            }.disabled(viewModel.isUploading)
            
            // 3. Gallery Button (Manual Add)
            PhotosPicker(selection: $photoSelection, matching: .images) {
                Image(systemName: "photo.on.rectangle").font(.title3).frame(width: 50, height: 50).background(Color.white).foregroundColor(.blue).cornerRadius(16).shadow(radius: 2)
            }.disabled(viewModel.isUploading)
            
        }.padding(.horizontal, 16)
    }
}
