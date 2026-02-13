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
    
    // ViewModel
    @StateObject private var viewModel: ClosetViewModel
    
    // Grid Filter State
    @State private var selectedCategoryFilter: ClothingCategory? = nil
    
    // Selection & State
    @State private var selectedItemIDs: Set<String> = []
    
    // --- UPDATED: BULK UPLOAD STATE ---
    @State private var photoSelection: [PhotosPickerItem] = [] // Changed to Array
    @State private var showBulkAddSheet = false                // Changed to Bulk Sheet
    
    // Smart Add (Camera/LiDAR)
    @State private var showSmartScan = false
    
    // Zoom & Delete
    @State private var zoomedItem: ClothingItem? = nil
    @State private var itemToDelete: ClothingItem?
    @State private var showingDeleteAlert = false
    
    // MARK: - DRAWER GESTURE STATE
    private let screenHeight = UIScreen.main.bounds.height
    private var maxOpenOffset: CGFloat { screenHeight * 0.12 }
    private var midOffset: CGFloat { screenHeight * 0.48 }
    @State private var currentDrawerOffset: CGFloat = UIScreen.main.bounds.height * 0.48
    @State private var dragOffset: CGFloat = 0
    
    let fitPickGold = Color("fitPickGold")
    
    // MARK: - Init
    init(targetUserEmail: String? = nil, targetUsername: String? = nil) {
        self.targetUserEmail = targetUserEmail
        self.targetUsername = targetUsername
        _viewModel = StateObject(wrappedValue: ClosetViewModel(targetEmail: targetUserEmail))
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                
                // LAYER 1: Header
                VStack {
                    ClosetHeaderView(
                        viewModel: viewModel,
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
                
                // LAYER 2: Drawer
                VStack(spacing: 0) {
                    
                    // --- DRAGGABLE HEADER ---
                    VStack(spacing: 0) {
                        ZStack {
                            Capsule().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 5).padding(.vertical, 12)
                        }.frame(height: 30)
                        
                        // UPDATED: Action Buttons now accept the [PhotosPickerItem] array
                        ClosetActionButtons(
                            viewModel: viewModel,
                            selectedItemIDs: selectedItemIDs,
                            showSmartScan: $showSmartScan,
                            photoSelection: $photoSelection,
                            onTryOn: {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    currentDrawerOffset = midOffset
                                }
                                Task { await viewModel.generateVirtualTryOn(selectedItemIDs: selectedItemIDs) }
                            },
                            isGuest: targetUserEmail != nil
                        )
                        .padding(.bottom, 10)
                        
                        ClosetFilterView(selectedCategory: $selectedCategoryFilter).padding(.bottom, 10)
                    }
                    .background(Color.white)
                    .gesture(DragGesture().onChanged(handleDragChanged).onEnded(handleDragEnded))
                    
                    // --- GRID ---
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
                        .padding(.bottom, 250)
                    }
                    .scrollDisabled(currentDrawerOffset > midOffset + 50)
                }
                .background(Color.white)
                .clipShape(RoundedCorner(radius: 30, corners: [.topLeft, .topRight]))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                .frame(height: screenHeight * 0.90)
                .offset(y: currentDrawerOffset + dragOffset)
                
                // LAYER 3: Zoom Overlay
                if let item = zoomedItem {
                    ZoomOverlayView(
                        item: item,
                        onDismiss: { withAnimation(.easeInOut) { zoomedItem = nil } },
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
            
            // 1. Smart Scan
            .sheet(isPresented: $showSmartScan) {
                // Uses the updated MVVM Smart Sheet
                SmartAddItemSheet(viewModel: viewModel)
            }
            
            // 2. UPDATED: Bulk Manual Add
            // Detect when photos are selected
            .onChange(of: photoSelection) { _, newItems in
                if !newItems.isEmpty {
                    showBulkAddSheet = true
                }
            }
            // Present the new Bulk Sheet
            .sheet(isPresented: $showBulkAddSheet) {
                BulkAddItemSheet(viewModel: viewModel, pickerItems: photoSelection)
                    .onDisappear {
                        photoSelection = [] // Clear selection when sheet closes
                    }
            }
            
            // 3. Delete Alert
            .alert("Delete?", isPresented: $showingDeleteAlert, presenting: itemToDelete) { i in
                Button("Delete", role: .destructive) { viewModel.deleteItem(i) }
            }
        }
    }
    
    // MARK: - Gesture Logic
    private func handleDragChanged(_ value: DragGesture.Value) {
        let newOffset = currentDrawerOffset + value.translation.height
        if newOffset > maxOpenOffset - 50 && newOffset < midOffset + 20 {
            dragOffset = value.translation.height
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        let predictedEnd = currentDrawerOffset + value.translation.height + (value.predictedEndLocation.y - value.location.y)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            let distanceToTop = abs(predictedEnd - maxOpenOffset)
            let distanceToMid = abs(predictedEnd - midOffset)
            if distanceToTop < distanceToMid { currentDrawerOffset = maxOpenOffset }
            else { currentDrawerOffset = midOffset }
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
            
            if isSelected {
                RoundedRectangle(cornerRadius: 16).stroke(Color.blue, lineWidth: 3).frame(height: 140)
                Image(systemName: "checkmark.circle.fill").font(.title3).foregroundColor(.blue).background(Circle().fill(.white)).padding(4)
            }
            if !item.size.isEmpty {
                Text(item.size).font(.caption2.bold()).padding(4).background(.ultraThinMaterial).clipShape(Capsule()).padding([.top, .leading], 4).frame(maxWidth: .infinity, alignment: .topLeading)
            }
            if isOwner && !isSelected {
                Button(action: onDelete) {
                    Image(systemName: "xmark").font(.caption).foregroundColor(.white).padding(6).background(Color.black.opacity(0.4)).clipShape(Circle())
                }.padding(6).frame(maxWidth: .infinity, maxHeight: 140, alignment: .bottomTrailing)
            }
        }
    }
}

struct ZoomOverlayView: View {
    let item: ClothingItem
    let onDismiss: () -> Void
    let isOwner: Bool
    var body: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea().onTapGesture(perform: onDismiss)
            VStack(spacing: 20) {
                KFImage(URL(string: item.remoteURL)).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 12)).padding()
                VStack(spacing: 8) {
                    Text(item.subCategory).font(.title2.bold()).foregroundColor(.white)
                    HStack(spacing: 10) {
                        Text(item.size.isEmpty ? "No Size" : "Size: \(item.size)").font(.headline).foregroundColor(.gray)
                    }.padding(.vertical, 4).padding(.horizontal, 12).background(Color.white.opacity(0.1)).cornerRadius(10)
                }
            }
            VStack { HStack { Spacer(); Button(action: onDismiss) { Image(systemName: "xmark.circle.fill").font(.largeTitle).foregroundColor(.white).padding() } }; Spacer() }
        }
    }
}

// MARK: - UPDATED ACTION BUTTONS
struct ClosetActionButtons: View {
    @ObservedObject var viewModel: ClosetViewModel
    let selectedItemIDs: Set<String>
    
    @Binding var showSmartScan: Bool
    
    // UPDATED: Now accepts an ARRAY of photos for bulk upload
    @Binding var photoSelection: [PhotosPickerItem]
    
    var onTryOn: () -> Void
    let isGuest: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 1. Try On Button
            Button(action: onTryOn) {
                Group {
                    if viewModel.isGeneratingTryOn { HStack { ProgressView().tint(.white); Text("Styling...") } }
                    else { HStack { Image(systemName: "sparkles"); Text(selectedItemIDs.count > 0 ? "Try On (\(selectedItemIDs.count))" : "Try On") }.bold() }
                }
                .font(.subheadline).frame(height: 50).frame(maxWidth: .infinity)
                .background(LinearGradient(colors: selectedItemIDs.isEmpty ? [.gray] : [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .foregroundColor(.white).cornerRadius(16)
            }
            .disabled(selectedItemIDs.isEmpty || viewModel.isGeneratingTryOn)

            // 2. Add Buttons
            if !isGuest {
                // A. Smart Scan
                Button(action: { showSmartScan = true }) {
                    VStack { Image(systemName: "camera.viewfinder").font(.title3) }.frame(width: 50, height: 50)
                        .background(Color.blue.opacity(0.1)).foregroundColor(.blue).cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.blue.opacity(0.3), lineWidth: 1))
                }.disabled(viewModel.isUploading)
                
                // B. Gallery Picker (BULK MODE)
                // matching: .images allows selecting multiple
                // maxSelectionCount: 10 sets a limit
                PhotosPicker(selection: $photoSelection, maxSelectionCount: 10, matching: .images) {
                    VStack { Image(systemName: "photo.on.rectangle.angled").font(.title3) }.frame(width: 50, height: 50)
                        .background(Color.orange.opacity(0.1)).foregroundColor(.orange).cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                }.disabled(viewModel.isUploading)
            }
        }.padding(.horizontal, 16)
    }
}
