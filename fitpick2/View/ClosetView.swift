//
//  ClosetView.swift
//  fitpick
//
//  Created by Bryan Gavino on 1/19/26.
//

import SwiftUI
import PhotosUI
import Kingfisher
import FirebaseAuth

struct ClosetView: View {
    // MARK: - Properties
    
    // Guest Mode Properties
    var targetUserEmail: String?
    var targetUsername: String?
    
    // ViewModel (Initialized in init)
    @StateObject private var viewModel: ClosetViewModel
    
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
    private var midOffset: CGFloat { screenHeight * 0.48 }          // Mid (Half/Half)

    // State: Initialize to MID Offset
    @State private var currentDrawerOffset: CGFloat = UIScreen.main.bounds.height * 0.48
    @State private var dragOffset: CGFloat = 0
    
    let fitPickGold = Color("fitPickGold") // Ensure you have this in Assets, or use .yellow/gold
    
    // MARK: - Custom Init (Crucial for Guest Mode)
    init(targetUserEmail: String? = nil, targetUsername: String? = nil) {
        self.targetUserEmail = targetUserEmail
        self.targetUsername = targetUsername
        // Initialize VM with target email
        _viewModel = StateObject(wrappedValue: ClosetViewModel(targetEmail: targetUserEmail))
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                
                // MARK: LAYER 1 - Background (Virtual Mirror / Header)
                VStack {
                    ClosetHeaderView(
                        viewModel: viewModel, // Pass full VM
                        tryOnImage: $viewModel.generatedTryOnImage,
                        tryOnMessage: $viewModel.tryOnMessage,
                        onSave: { Task { await viewModel.saveCurrentLook() } },
                        isSaving: viewModel.isSavingTryOn,
                        isSaved: viewModel.isSaved,
                        isGuest: targetUserEmail != nil
                    )
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, targetUserEmail != nil ? 10 : 20)
                }
                .background(Color(uiColor: .systemGroupedBackground))
                
                // MARK: LAYER 2 - Draggable Wardrobe Drawer
                VStack(spacing: 0) {
                    
                    // --- DRAGGABLE HEADER START ---
                    VStack(spacing: 0) {
                        // 1. Grabber Handle
                        ZStack {
                            Capsule()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 40, height: 5)
                                .padding(.vertical, 12)
                        }
                        .frame(height: 30)
                        
                        // 2. Action Buttons (Camera, Gallery, Try-On)
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
                                // Trigger Logic
                                Task { await viewModel.generateVirtualTryOn(selectedItemIDs: selectedItemIDs) }
                            },
                            isGuest: targetUserEmail != nil
                        )
                        .padding(.bottom, 10)
                        
                        // 3. Filters
                        ClosetFilterView(selectedCategory: $selectedCategoryFilter)
                            .padding(.bottom, 10)
                    }
                    .background(Color.white) // Important: Makes the whitespace draggable
                    // ATTACH GESTURE TO THE WHOLE HEADER
                    .gesture(
                        DragGesture()
                            .onChanged(handleDragChanged)
                            .onEnded(handleDragEnded)
                    )
                    // --- DRAGGABLE HEADER END ---
                    
                    // 4. Scrollable Grid (Independent)
                    ScrollView {
                        InventoryGrid(
                            viewModel: viewModel,
                            selectedItemIDs: $selectedItemIDs,
                            itemToDelete: $itemToDelete,
                            showingDeleteAlert: $showingDeleteAlert,
                            selectedCategory: selectedCategoryFilter,
                            zoomedItem: $zoomedItem,
                            isOwner: targetUserEmail == nil
                        )
                        // Massive padding to ensure Delete button clears menus
                        .padding(.bottom, 250)
                    }
                    // Prevent scrolling conflict when drawer is closed/mid
                    .scrollDisabled(currentDrawerOffset > midOffset + 50)
                }
                .background(Color.white)
                .clipShape(RoundedCorner(radius: 30, corners: [.topLeft, .topRight]))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                .frame(height: screenHeight * 0.90)
                .offset(y: currentDrawerOffset + dragOffset)
                // .offset(y: 30) // Safe area correction
                
                // MARK: LAYER 3 - Zoom Overlay
                if let item = zoomedItem {
                    ZoomOverlayView(
                        item: item,
                        onDismiss: { withAnimation(.easeInOut) { zoomedItem = nil } },
                        // Note: Only owners can actually update size
                        onSaveSize: { _ in }, // Placeholder if not needed, or implement VM update
                        isOwner: targetUserEmail == nil
                    )
                    .zIndex(2)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(targetUserEmail == nil ? "My Closet" : "@\(targetUsername ?? "User")'s Closet")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            
            // MARK: - Sheets
            
            // 1. Smart Scan (Camera/LiDAR)
            .sheet(isPresented: $showSmartScan) {
                SmartAddItemSheet(viewModel: viewModel)
            }
            
            // 2. Manual Add (Gallery)
            .onChange(of: photoSelection) { _, val in
                Task {
                    if let d = try? await val?.loadTransferable(type: Data.self), let u = UIImage(data: d) {
                        await MainActor.run {
                            imageForManualAdd = u
                            showManualAddSheet = true
                            photoSelection = nil // Reset picker
                        }
                    }
                }
            }
            .sheet(isPresented: $showManualAddSheet) {
                if let img = imageForManualAdd {
                    AddItemSheet(image: img, viewModel: viewModel)
                }
            }
            
            // 3. Delete Alert
            .alert("Delete?", isPresented: $showingDeleteAlert, presenting: itemToDelete) { i in
                Button("Delete", role: .destructive) {
                    // Assuming you have a delete function in VM
                    // viewModel.deleteItem(i)
                }
            }
        }
    }
    
    // MARK: - Gesture Logic
    
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
    let isOwner: Bool
    
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            let items = viewModel.clothingItems.filter { selectedCategory == nil ? true : $0.category == selectedCategory }
            if items.isEmpty { ContentUnavailableView("No Items", systemImage: "hanger").padding(.top, 50) }
            else {
                ForEach(items) { item in
                    InventoryItemCard(
                        item: item, isSelected: selectedItemIDs.contains(item.id),
                        isOwner: isOwner,
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
    let item: ClothingItem; let isSelected: Bool; let isOwner: Bool; let onTap: () -> Void; let onDelete: () -> Void; let onLongPress: () -> Void
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 1. Image Layer (Kingfisher)
            KFImage(URL(string: item.remoteURL))
                .placeholder { Color.gray.opacity(0.1) }
                .cacheOriginalImage()
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: 140)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
                .onLongPressGesture(perform: onLongPress)
            
            // 2. Selection Border
            if isSelected {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue, lineWidth: 3)
                    .frame(height: 140)
            }
            
            // 3. Selection Icon
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                    .background(Circle().fill(.white))
                    .padding(4)
            }
            
            // 4. Size Tag
            if !item.size.isEmpty {
                Text(item.size.isEmpty ? "Unknown" : item.size)
                    .font(.caption2.bold())
                    .padding(4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding([.top, .leading], 4)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            
            // 5. Delete Button (Hidden for Guests)
            if isOwner && !isSelected {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: 140, alignment: .bottomTrailing)
            }
        }
    }
}

struct ZoomOverlayView: View {
    let item: ClothingItem
    let onDismiss: () -> Void
    let onSaveSize: (String) -> Void
    let isOwner: Bool
    
    @State private var isEditing = false
    @State private var editedSize: String = ""
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea().onTapGesture(perform: onDismiss)
            
            VStack(spacing: 20) {
                KFImage(URL(string: item.remoteURL))
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                
                VStack(spacing: 8) {
                    Text(item.subCategory)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    HStack(spacing: 10) {
                        // The size is always displayed here
                        Text(item.size.isEmpty ? "No Size" : "Size: \(item.size)")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        // Only show the interactive edit button for owners
                        if isOwner {
                            Button(action: {
                                editedSize = item.size
                                isEditing = true
                            }) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                                    .background(Circle().fill(.white))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                }
            }
            
            // Close Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
            }
        }
        .alert("Edit Size", isPresented: $isEditing) {
            TextField("Size", text: $editedSize)
            Button("Save") { onSaveSize(editedSize) }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Action Buttons (Functional: Try On, Camera, Gallery)
struct ClosetActionButtons: View {
    @ObservedObject var viewModel: ClosetViewModel
    let selectedItemIDs: Set<String>
    
    // Bindings
    @Binding var showSmartScan: Bool
    @Binding var photoSelection: PhotosPickerItem?
    
    // Actions
    var onTryOn: () -> Void
    
    // Guest Mode
    let isGuest: Bool

    var body: some View {
        HStack(spacing: 12) {
            
            // 1. Try On Button (Dynamic Width)
            Button(action: onTryOn) {
                Group {
                    if viewModel.isGeneratingTryOn {
                        HStack { ProgressView().tint(.white); Text("Styling...") }
                    } else {
                        HStack {
                            Image(systemName: "sparkles")
                            Text(selectedItemIDs.count > 0 ? "Try On (\(selectedItemIDs.count))" : "Try On")
                        }
                        .bold()
                    }
                }
                .font(.subheadline)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(LinearGradient(colors: selectedItemIDs.isEmpty ? [.gray] : [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .foregroundColor(.white)
                .cornerRadius(16)
            }
            .disabled(selectedItemIDs.isEmpty || viewModel.isGeneratingTryOn)

            // 2. Add Buttons (Hidden if Guest)
            if !isGuest {
                // A. Smart Scan (Camera)
                Button(action: { showSmartScan = true }) {
                    VStack {
                        Image(systemName: "camera.viewfinder")
                            .font(.title3)
                    }
                    .frame(width: 50, height: 50)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.blue.opacity(0.3), lineWidth: 1))
                }
                .disabled(viewModel.isUploading)
                
                // B. Gallery Picker (Manual)
                PhotosPicker(selection: $photoSelection, matching: .images) {
                    VStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title3)
                    }
                    .frame(width: 50, height: 50)
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                }
                .disabled(viewModel.isUploading)
            }
            
        }
        .padding(.horizontal, 16)
    }
}
