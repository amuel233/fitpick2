//
//  ClosetView.swift
//  fitpick
//
//  Created by FitPick on 2/13/26.
//

import SwiftUI
import PhotosUI
import Kingfisher
import FirebaseAuth

struct ClosetView: View {
    // MARK: - Properties
    var targetUserEmail: String?
    var targetUsername: String?
    
    @StateObject private var viewModel: ClosetViewModel
    @ObservedObject var firestoreManager = FirestoreManager.shared
    
    // UI State
    @State private var showCamera = false
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var showBulkSheet = false
    @State private var zoomedItem: ClothingItem? = nil
    @State private var itemToDelete: ClothingItem?
    @State private var showingDeleteAlert = false
    @State private var showHistory = false
    
    // Drawer Logic
    @State private var dragOffset: CGFloat = 0
    @State private var position: DrawerPosition = .middle
    private let screenHeight = UIScreen.main.bounds.height
    
    init(targetUserEmail: String? = nil, targetUsername: String? = nil) {
        self.targetUserEmail = targetUserEmail
        self.targetUsername = targetUsername
        _viewModel = StateObject(wrappedValue: ClosetViewModel(targetEmail: targetUserEmail))
    }
    
    enum DrawerPosition {
        case top, middle, bottom
        
        var offsetMultiplier: CGFloat {
            switch self {
            case .top: return 0.12
            case .middle: return 0.40 // Updated from 0.48
            case .bottom: return 0.65 // Added new position
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                
                // MARK: - LAYER 0: LUXE STUDIO BACKGROUND
                ZStack {
                    Color.luxeSpotlightGradient.ignoresSafeArea()
                    
                    // Ambient Glows
                    GeometryReader { geo in
                        ZStack {
                            Circle().fill(Color.luxeEcru).frame(width: 400, height: 400)
                                .blur(radius: 150).opacity(0.08).offset(x: -150, y: -200)
                            Circle().fill(Color.luxeFlax).frame(width: 300, height: 300)
                                .blur(radius: 120).opacity(0.05).offset(x: 200, y: 100)
                        }
                    }
                }.zIndex(0)
                
                // MARK: - LAYER 1: AVATAR HEADER
                VStack {
                    ClosetHeaderView(
                        viewModel: viewModel,
                        tryOnImage: $viewModel.generatedTryOnImage,
                        tryOnMessage: $viewModel.tryOnMessage,
                        onSave: { Task { await viewModel.saveCurrentLook() } },
                        onShowHistory: { showHistory = true },
                        isSaving: viewModel.isSavingTryOn,
                        isSaved: viewModel.isSaved,
                        isGuest: targetUserEmail != nil
                    )
                    .padding(.top, 10)
                    Spacer()
                }
                .zIndex(1)
                
            // MARK: - LAYER 2: ULTRA-LUXE GLASS DRAWER
                            GeometryReader { geometry in
                                VStack(spacing: 0) {
                                    
                                    // --- GLASS HEADER ---
                                    VStack(spacing: 0) {
                                        // 1. Handle
                                        Capsule().fill(Color.luxeGoldGradient)
                                            .frame(width: 40, height: 4).padding(.vertical, 15).shadow(color: .luxeFlax.opacity(0.6), radius: 8)
                                        
                                        // 2. Actions
                                        ClosetActionButtons(
                                            viewModel: viewModel,
                                            selectedItemIDs: viewModel.selectedItemIDs,
                                            showCamera: $showCamera,
                                            selectedPickerItems: $selectedPickerItems,
                                            onTryOn: { withAnimation { position = .middle } },
                                            isGuest: targetUserEmail != nil
                                        ).padding(.bottom, 20)
                                        
                                        // 3. Filters
                                        ClosetFilterView(selectedCategory: $viewModel.selectedCategory).padding(.bottom, 20)
                                    }
                                    .background(.ultraThinMaterial).environment(\.colorScheme, .dark)
                                    
                                    // --- CONTENT ---
                                    ScrollView {
                                        InventoryGrid(
                                            viewModel: viewModel,
                                            itemToDelete: $itemToDelete,
                                            showingDeleteAlert: $showingDeleteAlert,
                                            zoomedItem: $zoomedItem,
                                            isOwner: targetUserEmail == nil
                                        )
                                        // ✅ FIXED: Increased padding from 160 to 220
                                        // This ensures the Delete button (at the bottom of the card) clears the Tab Bar
                                        .padding(.bottom, 220)
                                    }
                                    .background(.ultraThinMaterial).environment(\.colorScheme, .dark)
                                }
                                .clipShape(RoundedCorner(radius: 35, corners: [.topLeft, .topRight]))
                                .overlay(RoundedCorner(radius: 35, corners: [.topLeft, .topRight]).stroke(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.5))
                                .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: -10)
                                .offset(y: (screenHeight * position.offsetMultiplier) + dragOffset)
                                .allowsHitTesting(true)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            let translation = value.translation.height
                                            
                                            // ✅ LOGIC: Add resistance when dragging past limits
                                            if position == .top && translation < 0 {
                                                dragOffset = translation / 3 // Resist pulling up
                                            } else if position == .bottom && translation > 0 {
                                                dragOffset = translation / 3 // Resist pulling down
                                            } else {
                                                dragOffset = translation
                                            }
                                        }
                                        .onEnded { value in
                                            let currentY = (screenHeight * position.offsetMultiplier) + value.translation.height + (value.predictedEndLocation.y - value.location.y) * 0.2
                                            
                                            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                                                // ✅ LOGIC: Calculate distance to all 3 positions
                                                let distTop = abs(currentY - (screenHeight * DrawerPosition.top.offsetMultiplier))
                                                let distMid = abs(currentY - (screenHeight * DrawerPosition.middle.offsetMultiplier))
                                                let distBot = abs(currentY - (screenHeight * DrawerPosition.bottom.offsetMultiplier))
                                                
                                                // Snap to closest
                                                if distTop < distMid && distTop < distBot { position = .top }
                                                else if distMid < distTop && distMid < distBot { position = .middle }
                                                else { position = .bottom }
                                                
                                                dragOffset = 0
                                            }
                                        }
                                )
                            }
                            .edgesIgnoringSafeArea(.bottom)
                            .allowsHitTesting(true)
                            .zIndex(2)
                
                // MARK: - LAYER 3: ZOOM OVERLAY
                if let item = zoomedItem {
                    ZoomOverlayView(item: item, onDismiss: { withAnimation { zoomedItem = nil } }, isOwner: targetUserEmail == nil)
                        .zIndex(3).transition(.opacity)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showCamera) { SmartAddItemSheet(viewModel: viewModel) }
            .onChange(of: selectedPickerItems) { _, newItems in if !newItems.isEmpty { showBulkSheet = true } }
            .sheet(isPresented: $showBulkSheet, onDismiss: { selectedPickerItems = [] }) { BulkAddItemSheet(viewModel: viewModel, pickerItems: selectedPickerItems) }
            .alert("Delete Item?", isPresented: $showingDeleteAlert, presenting: itemToDelete) { item in
                Button("Delete", role: .destructive) { viewModel.deleteItem(item) }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showHistory) { HistorySheetView(viewModel: viewModel, isPresented: $showHistory) }
        }
    }
}

// MARK: - Action Buttons
struct ClosetActionButtons: View {
    @ObservedObject var viewModel: ClosetViewModel
    let selectedItemIDs: Set<String>
    @Binding var showCamera: Bool
    @Binding var selectedPickerItems: [PhotosPickerItem]
    var onTryOn: () -> Void
    let isGuest: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { onTryOn(); Task { await viewModel.generateVirtualTryOn(selectedItemIDs: selectedItemIDs) } }) {
                HStack(spacing: 8) {
                    if viewModel.isGeneratingTryOn { ProgressView().tint(.black) } else {
                        Image(systemName: "sparkles"); Text(selectedItemIDs.count > 0 ? "Try On (\(selectedItemIDs.count))" : "Try On")
                    }
                }
                .font(.system(size: 16, weight: .bold, design: .serif)).foregroundColor(.black).frame(height: 54).frame(maxWidth: .infinity)
                .background(
                    LinearGradient(colors: selectedItemIDs.isEmpty ? [Color(white: 0.2)] : [.luxeEcru, .luxeFlax, .luxeEcru], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 1))
                .shadow(color: selectedItemIDs.isEmpty ? .clear : .luxeEcru.opacity(0.4), radius: 10, x: 0, y: 5)
            }.disabled(selectedItemIDs.isEmpty || viewModel.isGeneratingTryOn)

            if !isGuest {
                GlassIconButton(icon: "camera.fill", action: { showCamera = true })
                PhotosPicker(selection: $selectedPickerItems, maxSelectionCount: 10, matching: .images) { GlassIconView(icon: "photo.on.rectangle") }
            }
        }.padding(.horizontal, 20)
    }
}

struct GlassIconButton: View { let icon: String; let action: () -> Void; var body: some View { Button(action: action) { GlassIconView(icon: icon) } } }
struct GlassIconView: View { let icon: String; var body: some View { Image(systemName: icon).font(.title3).foregroundColor(.luxeBeige).frame(width: 54, height: 54).background(.ultraThinMaterial).environment(\.colorScheme, .dark).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 0.5)).shadow(color: .black.opacity(0.2), radius: 5) } }

// MARK: - Filters
struct ClosetFilterView: View {
    @Binding var selectedCategory: ClothingCategory?
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                FilterIcon(image: Image(systemName: "square.grid.2x2"), isSelected: selectedCategory == nil, onTap: { withAnimation { selectedCategory = nil } })
                ForEach(ClothingCategory.allCases, id: \.self) { cat in FilterIcon(image: iconForCategory(cat), isSelected: selectedCategory == cat, onTap: { withAnimation { selectedCategory = cat } }) }
            }.padding(.horizontal, 24)
        }
    }
    func iconForCategory(_ category: ClothingCategory) -> Image {
        switch category { case .top: return Image(systemName: "tshirt"); case .bottom: return Image("icon-pants"); case .shoes: return Image(systemName: "shoe"); case .accessories: return Image(systemName: "sunglasses.fill") }
    }
}

struct FilterIcon: View {
    let image: Image; let isSelected: Bool; let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            image.renderingMode(.template).resizable().scaledToFit().frame(width: 20, height: 20).foregroundColor(isSelected ? .black : .luxeEcru)
                .frame(width: 48, height: 48).background(isSelected ? Color.luxeEcru : Color.black.opacity(0.3)).background(.ultraThinMaterial).clipShape(Circle())
                .overlay(Circle().stroke(isSelected ? Color.luxeFlax : Color.white.opacity(0.1), lineWidth: 1)).shadow(color: isSelected ? .luxeEcru.opacity(0.3) : .clear, radius: 8)
        }
    }
}

// MARK: - Grid
struct InventoryGrid: View {
    @ObservedObject var viewModel: ClosetViewModel; @Binding var itemToDelete: ClothingItem?; @Binding var showingDeleteAlert: Bool; @Binding var zoomedItem: ClothingItem?; let isOwner: Bool
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            let items = viewModel.filteredItems
            if items.isEmpty { VStack(spacing: 15) { Image(systemName: "hanger").font(.system(size: 40)).foregroundColor(.white.opacity(0.1)); Text("Closet is empty").font(.caption).foregroundColor(.gray) }.padding(.top, 50) }
            else { ForEach(items) { item in InventoryItemCard(item: item, isSelected: viewModel.selectedItemIDs.contains(item.id), isOwner: isOwner, onTap: { viewModel.toggleSelection(item) }, onDelete: { itemToDelete = item; showingDeleteAlert = true }, onLongPress: { let g = UIImpactFeedbackGenerator(style: .medium); g.impactOccurred(); withAnimation { zoomedItem = item } }) } }
        }.padding(.horizontal, 20).padding(.top, 10)
    }
}

struct InventoryItemCard: View {
    let item: ClothingItem; let isSelected: Bool; let isOwner: Bool; let onTap: () -> Void; let onDelete: () -> Void; let onLongPress: () -> Void
    var body: some View {
        ZStack(alignment: .topTrailing) {
            CachedImageView(urlString: item.remoteURL).frame(minWidth: 0, maxWidth: .infinity).frame(height: 150).clipped().overlay(Color.black.opacity(isSelected ? 0.4 : 0)).clipShape(RoundedRectangle(cornerRadius: 16)).contentShape(Rectangle()).onTapGesture(perform: onTap).onLongPressGesture(perform: onLongPress)
            if isSelected { RoundedRectangle(cornerRadius: 16).stroke(Color.luxeGoldGradient, lineWidth: 2).frame(height: 150); Image(systemName: "checkmark.circle.fill").foregroundColor(.luxeFlax).background(Circle().fill(.black)).padding(6) }
            if isOwner && !isSelected { Button(action: onDelete) { Image(systemName: "xmark").font(.caption2.bold()).foregroundColor(.white.opacity(0.7)).padding(6).background(.ultraThinMaterial).clipShape(Circle()) }.padding(6).frame(maxWidth: .infinity, maxHeight: 150, alignment: .bottomTrailing) }
        }.overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
    }
}

// MARK: - Zoom Overlay
struct ZoomOverlayView: View {
    let item: ClothingItem; let onDismiss: () -> Void; let isOwner: Bool
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark).ignoresSafeArea().onTapGesture(perform: onDismiss)
            VStack(spacing: 25) {
                CachedImageView(urlString: item.remoteURL).scaledToFit().clipShape(RoundedRectangle(cornerRadius: 20)).shadow(color: .black.opacity(0.5), radius: 30).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 0.5)).padding()
                VStack(spacing: 8) {
                    Text(item.subCategory.uppercased()).font(.title2).fontWeight(.bold).foregroundColor(.luxeFlax).tracking(2)
                    if !item.size.isEmpty { Text("SIZE \(item.size)").font(.subheadline).foregroundColor(.luxeBeige).padding(.horizontal, 12).padding(.vertical, 6).background(.ultraThinMaterial).cornerRadius(8) }
                }
            }
            VStack { HStack { Spacer(); Button(action: onDismiss) { Image(systemName: "xmark").font(.title).foregroundColor(.white).padding().padding(.top, 40) } }; Spacer() }
        }
    }
}

// MARK: - History Views
struct HistorySheetView: View {
    @ObservedObject var viewModel: ClosetViewModel; @Binding var isPresented: Bool; @State private var selectedLook: SavedLook?; let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    var body: some View {
        NavigationStack {
            ZStack {
                Color.luxeRichCharcoal.ignoresSafeArea()
                ScrollView {
                    if viewModel.savedLooks.isEmpty { VStack(spacing: 20) { Image(systemName: "photo.stack").font(.system(size: 50)).foregroundColor(.luxeEcru.opacity(0.6)); Text("No saved looks").font(.headline).foregroundColor(.luxeBeige) }.padding(.top, 100) }
                    else { LazyVGrid(columns: columns, spacing: 12) { ForEach(viewModel.savedLooks) { look in ZStack(alignment: .topTrailing) { KFImage(URL(string: look.imageURL)).resizable().scaledToFill().frame(height: 150).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1)).contentShape(Rectangle()).onTapGesture { selectedLook = look }; Menu { Button("Restore", systemImage: "arrow.counterclockwise") { Task { await viewModel.restoreLook(look); isPresented = false } }; Button("Delete", systemImage: "trash", role: .destructive) { viewModel.deleteLook(look) } } label: { Image(systemName: "ellipsis").font(.headline).foregroundColor(.luxeRichCharcoal).padding(8).background(Color.luxeEcru).clipShape(Circle()) }.padding(6) } } }.padding() }
                }
            }
            .navigationTitle("Look History").navigationBarTitleDisplayMode(.inline).toolbarBackground(Color.luxeRichCharcoal, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar).toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { isPresented = false }.foregroundColor(.luxeEcru) } }
            .fullScreenCover(item: $selectedLook) { look in HistoryZoomView(look: look, viewModel: viewModel, parentSheetPresented: $isPresented, onDismiss: { selectedLook = nil }) }
        }
    }
}

struct HistoryZoomView: View {
    let look: SavedLook; @ObservedObject var viewModel: ClosetViewModel; @Binding var parentSheetPresented: Bool; var onDismiss: () -> Void
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea().onTapGesture { onDismiss() }
            KFImage(URL(string: look.imageURL)).resizable().scaledToFit()
            VStack { HStack { Spacer(); Button(action: onDismiss) { Image(systemName: "xmark").font(.title).foregroundColor(.white).padding().padding(.top, 40) } }; Spacer(); HStack(spacing: 16) { Button(action: { viewModel.deleteLook(look); onDismiss() }) { Image(systemName: "trash").font(.title3).foregroundColor(.white).frame(width: 70, height: 60).background(Color(white: 0.15)).cornerRadius(12) }; Button(action: { Task { await viewModel.restoreLook(look); onDismiss(); parentSheetPresented = false } }) { HStack { Image(systemName: "arrow.counterclockwise"); Text("Restore") }.bold().foregroundColor(.black).frame(maxWidth: .infinity).frame(height: 60).background(Color.luxeGoldGradient).cornerRadius(12) } }.padding(.horizontal, 20).padding(.bottom, 50) }
        }
    }
}

struct RoundedCorner: Shape { var radius: CGFloat = .infinity; var corners: UIRectCorner = .allCorners; func path(in rect: CGRect) -> Path { let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius)); return Path(path.cgPath) } }
extension View { func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View { clipShape(RoundedCorner(radius: radius, corners: corners)) } }
