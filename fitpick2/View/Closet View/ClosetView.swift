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
    
    var targetUserEmail: String?
    var targetUsername: String?
    
    // MVVM ViewModel
    @StateObject private var viewModel: ClosetViewModel
    
    // UI State
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var showBulkAddSheet = false
    @State private var showSmartScan = false
    @State private var zoomedItem: ClothingItem? = nil
    @State private var itemToDelete: ClothingItem?
    @State private var showingDeleteAlert = false
    
    // Drawer State
    private let screenHeight = UIScreen.main.bounds.height
    private var maxOpenOffset: CGFloat { screenHeight * 0.12 }
    private var midOffset: CGFloat { screenHeight * 0.48 }
    @State private var currentDrawerOffset: CGFloat = UIScreen.main.bounds.height * 0.48
    @State private var dragOffset: CGFloat = 0
    
    // MARK: - Init
    init(targetUserEmail: String? = nil, targetUsername: String? = nil) {
        self.targetUserEmail = targetUserEmail
        self.targetUsername = targetUsername
        _viewModel = StateObject(wrappedValue: ClosetViewModel(targetEmail: targetUserEmail))
    }
    
    // MARK: - Body (Simplified)
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                headerLayer      // Layer 1: Avatar/Mirror
                drawerLayer      // Layer 2: Draggable Closet
                zoomOverlayLayer // Layer 3: Zoom Modal
            }
            .navigationBarTitleDisplayMode(.inline)
            // Modifiers extracted to keep body clean
            .sheet(isPresented: $showSmartScan) { SmartAddItemSheet(viewModel: viewModel) }
            .onChange(of: photoSelection) { _, newItems in if !newItems.isEmpty { showBulkAddSheet = true } }
            .sheet(isPresented: $showBulkAddSheet) { BulkAddItemSheet(viewModel: viewModel, pickerItems: photoSelection).onDisappear { photoSelection = [] } }
            .alert("Delete?", isPresented: $showingDeleteAlert, presenting: itemToDelete) { i in
                Button("Delete", role: .destructive) { viewModel.deleteItem(i) }
            }
        }
    }
    
    // MARK: - Subviews (Extracted to fix Compiler Error)
    
    private var headerLayer: some View {
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
    }
    
    private var drawerLayer: some View {
        VStack(spacing: 0) {
            // 1. Draggable Header Area
            VStack(spacing: 0) {
                // Grab Handle
                ZStack {
                    Capsule().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 5).padding(.vertical, 12)
                }.frame(height: 30)
                
                // Buttons
                ClosetActionButtons(
                    viewModel: viewModel,
                    showSmartScan: $showSmartScan,
                    photoSelection: $photoSelection,
                    onTryOn: {
                        animateDrawerToMid()
                        Task { await viewModel.generateVirtualTryOn(selectedItemIDs: viewModel.selectedItemIDs) }
                    },
                    isGuest: targetUserEmail != nil
                )
                .padding(.bottom, 12)
                
                // Filters
                ClosetFilterView(selectedCategory: $viewModel.selectedCategory)
                    .padding(.bottom, 10)
            }
            .background(Color.white)
            .gesture(DragGesture().onChanged(handleDragChanged).onEnded(handleDragEnded))
            
            // 2. Scrollable Grid
            ScrollView {
                InventoryGrid(
                    viewModel: viewModel,
                    itemToDelete: $itemToDelete,
                    showingDeleteAlert: $showingDeleteAlert,
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
    }
    
    @ViewBuilder
    private var zoomOverlayLayer: some View {
        if let item = zoomedItem {
            ZoomOverlayView(
                item: item,
                onDismiss: { withAnimation(.easeInOut) { zoomedItem = nil } },
                isOwner: targetUserEmail == nil
            )
            .zIndex(2)
        }
    }
    
    // MARK: - Logic & Animations
    
    private func animateDrawerToMid() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentDrawerOffset = midOffset
        }
    }
    
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

// MARK: - Subcomponents (No Changes Needed Here)

struct ClosetFilterView: View {
    @Binding var selectedCategory: ClothingCategory?
    
    func iconName(for category: ClothingCategory?) -> String {
            // 1. Handle nil (The "All" category)
            guard let cat = category else { return "square.grid.2x2" }
            
            // 2. Handle all enum cases
            switch cat {
            case .top: return "tshirt"
            case .bottom: return "icon-pants" // Or your custom "icon-pants"
            case .shoes: return "shoe"
            case .accessories: return "bag"
            }
        }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChip(
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil,
                    action: { withAnimation { selectedCategory = nil } }
                )
                ForEach(ClothingCategory.allCases, id: \.self) { cat in
                    FilterChip(
                        icon: iconName(for: cat),
                        isSelected: selectedCategory == cat,
                        action: { withAnimation { selectedCategory = cat } }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct InventoryGrid: View {
    @ObservedObject var viewModel: ClosetViewModel
    @Binding var itemToDelete: ClothingItem?
    @Binding var showingDeleteAlert: Bool
    @Binding var zoomedItem: ClothingItem?
    let isOwner: Bool
    
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            let items = viewModel.filteredItems
            if items.isEmpty {
                ContentUnavailableView("No Items", systemImage: "hanger").padding(.top, 50)
            } else {
                ForEach(items) { item in
                    InventoryItemCard(
                        item: item,
                        isSelected: viewModel.selectedItemIDs.contains(item.id),
                        isOwner: isOwner,
                        onTap: { viewModel.toggleSelection(item) },
                        onDelete: { itemToDelete = item; showingDeleteAlert = true },
                        onLongPress: {
                            let g = UIImpactFeedbackGenerator(style: .medium)
                            g.impactOccurred()
                            withAnimation { zoomedItem = item }
                        }
                    )
                }
            }
        }.padding(.horizontal, 16)
    }
}

// Re-add FilterChip if missing in context, though it's likely in your project
struct FilterChip: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            // LOGIC: Check if it's our custom icon or a system symbol
            Group {
                if icon == "icon-pants" {
                    // 1. Custom Asset (Your SVG)
                    Image(icon)
                        .resizable()
                        .renderingMode(.template) // Allows it to be colored blue/black
                        .scaledToFit()
                        .padding(10) // Adjust padding since custom icons often fill the frame differently
                } else {
                    // 2. Apple System Symbol
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                }
            }
            .frame(width: 50, height: 40)
            .background(isSelected ? Color.black : Color.white)
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: isSelected ? 0 : 1)
            )
        }
    }
}

struct ClosetActionButtons: View {
    @ObservedObject var viewModel: ClosetViewModel
    @Binding var showSmartScan: Bool
    @Binding var photoSelection: [PhotosPickerItem]
    var onTryOn: () -> Void
    let isGuest: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTryOn) {
                Group {
                    if viewModel.isGeneratingTryOn { HStack { ProgressView().tint(.white); Text("Styling...") } }
                    else { HStack { Image(systemName: "sparkles"); Text(viewModel.selectedItemIDs.count > 0 ? "Try On (\(viewModel.selectedItemIDs.count))" : "Try On") }.bold() }
                }
                .font(.subheadline).frame(height: 50).frame(maxWidth: .infinity)
                .background(LinearGradient(colors: viewModel.selectedItemIDs.isEmpty ? [.gray] : [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .foregroundColor(.white).cornerRadius(16)
            }
            .disabled(viewModel.selectedItemIDs.isEmpty || viewModel.isGeneratingTryOn)

            if !isGuest {
                Button(action: { showSmartScan = true }) {
                    VStack { Image(systemName: "camera.viewfinder").font(.title3) }.frame(width: 50, height: 50)
                        .background(Color.blue.opacity(0.1)).foregroundColor(.blue).cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.blue.opacity(0.3), lineWidth: 1))
                }.disabled(viewModel.isUploading)
                
                PhotosPicker(selection: $photoSelection, maxSelectionCount: 10, matching: .images) {
                    VStack { Image(systemName: "photo.on.rectangle.angled").font(.title3) }.frame(width: 50, height: 50)
                        .background(Color.orange.opacity(0.1)).foregroundColor(.orange).cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                }.disabled(viewModel.isUploading)
            }
        }.padding(.horizontal, 16)
    }
}

// MARK: - Helper Shapes

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Zoom Overlay Helper

struct ZoomOverlayView: View {
    let item: ClothingItem
    let onDismiss: () -> Void
    let isOwner: Bool

    var body: some View {
        ZStack {
            // Dark Background
            Color.black.opacity(0.9)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            // Content
            VStack(spacing: 20) {
                // Large Image
                KFImage(URL(string: item.remoteURL))
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                    .shadow(radius: 10)

                // Info Text
                VStack(spacing: 8) {
                    Text(item.subCategory)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    if !item.size.isEmpty {
                        HStack(spacing: 10) {
                            Text("Size: \(item.size)")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
            }

            // Close Button (Top Right)
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding()
                            .padding(.top, 40) // Adjust for safe area
                    }
                }
                Spacer()
            }
        }
    }
}

struct InventoryItemCard: View {
    let item: ClothingItem
    let isSelected: Bool
    let isOwner: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Image
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
            
            // Selection Checkmark
            if isSelected {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue, lineWidth: 3)
                    .frame(height: 140)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                    .background(Circle().fill(.white))
                    .padding(4)
            }
            
            // Size Badge
            if !item.size.isEmpty {
                Text(item.size)
                    .font(.caption2.bold())
                    .padding(4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding([.top, .leading], 4)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            
            // Delete Button (Only for owner, when not selecting)
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
