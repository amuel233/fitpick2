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
            case .middle: return 0.40
            case .bottom: return 0.65
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                
                // MARK: - LAYER 0: LIQUID GLASS AMBIENT BACKGROUND
                LiquidGlassBackgroundView()
                    .zIndex(0)
                
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
                    .padding(.top, 6)
                    Spacer()
                }
                .zIndex(1)
                
                // MARK: - LAYER 2: ULTRA-LUXE LIQUID GLASS DRAWER
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        
                        // --- GLASS HEADER ---
                        VStack(spacing: 0) {
                            // 1. Handle
                            Capsule().fill(Color.luxeGoldGradient)
                                .frame(width: 44, height: 5).padding(.vertical, 14).shadow(color: .luxeFlax.opacity(0.5), radius: 6)
                            
                            // 2. Actions
                            ClosetActionButtons(
                                viewModel: viewModel,
                                selectedItemIDs: viewModel.selectedItemIDs,
                                showCamera: $showCamera,
                                selectedPickerItems: $selectedPickerItems,
                                onTryOn: { withAnimation { position = .middle } },
                                isGuest: targetUserEmail != nil
                            ).padding(.bottom, 18)
                            
                            // 3. Filters
                            ClosetFilterView(selectedCategory: $viewModel.selectedCategory).padding(.bottom, 18)
                        }
                        .background(Color.clear)
                        
                        // --- CONTENT ---
                        ScrollView {
                            InventoryGrid(
                                viewModel: viewModel,
                                itemToDelete: $itemToDelete,
                                showingDeleteAlert: $showingDeleteAlert,
                                zoomedItem: $zoomedItem,
                                isOwner: targetUserEmail == nil
                            )
                            .padding(.bottom, 220)
                        }
                        .background(Color.clear)
                    }
                    .background(
                        ZStack {
                            RoundedCorner(radius: 35, corners: [.topLeft, .topRight])
                                .fill(.ultraThinMaterial)
                            RoundedCorner(radius: 35, corners: [.topLeft, .topRight])
                                .fill(
                                    LinearGradient(
                                        colors: [Color.luxeRichCharcoal.opacity(0.70), Color.luxeDeepOnyx.opacity(0.90)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            RoundedCorner(radius: 35, corners: [.topLeft, .topRight])
                                .fill(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .white.opacity(0.18), location: 0.0),
                                            .init(color: .white.opacity(0.03), location: 0.20),
                                            .init(color: .clear, location: 0.50)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    )
                    .clipShape(RoundedCorner(radius: 35, corners: [.topLeft, .topRight]))
                    .overlay(
                        RoundedCorner(radius: 35, corners: [.topLeft, .topRight])
                            .stroke(
                                LinearGradient(
                                    stops: [
                                        .init(color: .white.opacity(0.65), location: 0.0),
                                        .init(color: Color.luxeFlax.opacity(0.40), location: 0.25),
                                        .init(color: .white.opacity(0.10), location: 0.60),
                                        .init(color: Color.luxeEcru.opacity(0.30), location: 1.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(color: Color.black.opacity(0.45), radius: 25, x: 0, y: -10)
                    .offset(y: (screenHeight * position.offsetMultiplier) + dragOffset)
                    .allowsHitTesting(true)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let translation = value.translation.height
                                if position == .top && translation < 0 {
                                    dragOffset = translation / 3
                                } else if position == .bottom && translation > 0 {
                                    dragOffset = translation / 3
                                } else {
                                    dragOffset = translation
                                }
                            }
                            .onEnded { value in
                                let currentY = (screenHeight * position.offsetMultiplier) + value.translation.height + (value.predictedEndLocation.y - value.location.y) * 0.2
                                
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                                    let distTop = abs(currentY - (screenHeight * DrawerPosition.top.offsetMultiplier))
                                    let distMid = abs(currentY - (screenHeight * DrawerPosition.middle.offsetMultiplier))
                                    let distBot = abs(currentY - (screenHeight * DrawerPosition.bottom.offsetMultiplier))
                                    
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
                    ZoomOverlayView(
                        item: item,
                        onDismiss: { withAnimation { zoomedItem = nil } },
                        isOwner: targetUserEmail == nil,
                        viewModel: viewModel
                    )
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
                .font(.system(size: 16, weight: .bold, design: .serif))
                .foregroundColor(selectedItemIDs.isEmpty ? .luxeBeige.opacity(0.3) : .black)
                .frame(height: 54)
                .frame(maxWidth: .infinity)
                .liquidGlassAdaptiveButton(isPrimary: !selectedItemIDs.isEmpty, cornerRadius: 16)
            }.disabled(selectedItemIDs.isEmpty || viewModel.isGeneratingTryOn)

            if !isGuest {
                GlassIconButton(icon: "camera.fill", action: { showCamera = true })
                PhotosPicker(selection: $selectedPickerItems, maxSelectionCount: 10, matching: .images) { GlassIconView(icon: "photo.on.rectangle") }
            }
        }.padding(.horizontal, 20)
    }
}

struct GlassIconButton: View { let icon: String; let action: () -> Void; var body: some View { Button(action: action) { GlassIconView(icon: icon) } } }
struct GlassIconView: View {
    let icon: String
    var body: some View {
        Image(systemName: icon)
            .font(.title3)
            .foregroundColor(.luxeBeige)
            .frame(width: 54, height: 54)
            .liquidGlassPill(cornerRadius: 16)
    }
}

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
                .frame(width: 48, height: 48)
                .liquidGlassAdaptiveButton(isPrimary: isSelected, cornerRadius: 24)
        }
    }
}

// MARK: - Grid (FIXED DIMENSIONS)
struct InventoryGrid: View {
    @ObservedObject var viewModel: ClosetViewModel
    @Binding var itemToDelete: ClothingItem?
    @Binding var showingDeleteAlert: Bool
    @Binding var zoomedItem: ClothingItem?
    let isOwner: Bool
    
    // ✅ 3 Uniform flexible columns
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            let items = viewModel.filteredItems
            if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "hanger")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(Color.luxeGoldGradient)
                    Text("Your Closet is Empty")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundColor(.luxeBeige)
                    Text("Tap the camera or gallery icons above to add your clothes.")
                        .font(.caption)
                        .foregroundColor(.luxeBeige.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .liquidGlassCard(cornerRadius: 20)
                .padding(.top, 40)
            } else {
                ForEach(items) { item in
                    InventoryItemCard(
                        item: item,
                        isSelected: viewModel.selectedItemIDs.contains(item.id),
                        isOwner: isOwner,
                        onTap: { viewModel.toggleSelection(item) },
                        onDelete: {
                            itemToDelete = item
                            showingDeleteAlert = true
                        },
                        onLongPress: {
                            let g = UIImpactFeedbackGenerator(style: .medium)
                            g.impactOccurred()
                            withAnimation { zoomedItem = item }
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
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
            // Frosted glass base backing
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .frame(height: 150)
            
            CachedImageView(urlString: item.remoteURL)
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: 150)
                .clipped()
                .overlay(Color.black.opacity(isSelected ? 0.35 : 0))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
                .onLongPressGesture(perform: onLongPress)
            
            if isSelected {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.luxeGoldGradient, lineWidth: 2.5)
                    .frame(height: 150)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.luxeFlax)
                    .background(Circle().fill(Color.black.opacity(0.7)))
                    .padding(8)
            }
            
            if isOwner && !isSelected {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 26, height: 26)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                        )
                }
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: 150, alignment: .bottomTrailing)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.40), location: 0.0),
                            .init(color: Color.luxeEcru.opacity(0.25), location: 0.3),
                            .init(color: .white.opacity(0.08), location: 0.7),
                            .init(color: Color.luxeFlax.opacity(0.20), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Zoom Overlay
struct ZoomOverlayView: View {
    let item: ClothingItem
    let onDismiss: () -> Void
    let isOwner: Bool
    @ObservedObject var viewModel: ClosetViewModel
    
    @State private var editedCategory: ClothingCategory
    @State private var editedSubCategory: String
    @State private var editedSize: String
    @State private var isEditing: Bool = false
    @State private var isSaving: Bool = false
    @State private var isAutoCategorizingItem: Bool = false
    
    init(item: ClothingItem, onDismiss: @escaping () -> Void, isOwner: Bool, viewModel: ClosetViewModel) {
        self.item = item
        self.onDismiss = onDismiss
        self.isOwner = isOwner
        self.viewModel = viewModel
        _editedCategory = State(initialValue: item.category)
        _editedSubCategory = State(initialValue: item.subCategory)
        _editedSize = State(initialValue: item.size)
    }

    var body: some View {
        ZStack {
            LiquidGlassBackgroundView()
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.85))
                .environment(\.colorScheme, .dark)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            
            VStack(spacing: 20) {
                // 1. Zoomed Image
                CachedImageView(urlString: item.remoteURL)
                    .scaledToFit()
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.40)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .liquidGlassCard(cornerRadius: 24)
                    .padding(.horizontal, 24)
                
                // 2. Info / Edit Section
                VStack(spacing: 14) {
                    if isEditing {
                        VStack(spacing: 16) {
                            Button(action: {
                                isAutoCategorizingItem = true
                                Task {
                                    if let url = URL(string: item.remoteURL),
                                       let (data, _) = try? await URLSession.shared.data(from: url),
                                       let downloadedImg = UIImage(data: data) {
                                        if let result = await viewModel.autoCategorizeClothing(image: downloadedImg) {
                                            await MainActor.run {
                                                editedCategory = result.category
                                                editedSubCategory = result.subcategory
                                                if editedSize.isEmpty && result.category == .accessories {
                                                    editedSize = "One Size"
                                                }
                                            }
                                        }
                                    }
                                    await MainActor.run { isAutoCategorizingItem = false }
                                }
                            }) {
                                HStack(spacing: 6) {
                                    if isAutoCategorizingItem {
                                        ProgressView().tint(.black).scaleEffect(0.8)
                                        Text("Categorizing...").font(.caption.bold())
                                    } else {
                                        Image(systemName: "sparkles")
                                        Text("Auto-Categorize").font(.caption.bold())
                                    }
                                }
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .liquidGlassGoldButton(cornerRadius: 10)
                            }
                            .disabled(isAutoCategorizingItem)
                            
                            Picker("Category", selection: $editedCategory) {
                                ForEach(ClothingCategory.allCases) { category in
                                    Text(category.rawValue).tag(category)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .onAppear {
                                UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(Color.luxeFlax)
                                UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
                                UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
                            }

                            TextField("Subcategory (e.g. Blouse)", text: $editedSubCategory)
                                .textFieldStyle(GlassTextFieldStyle())
                                .multilineTextAlignment(.center)
                            
                            TextField("Size (e.g. M)", text: $editedSize)
                                .textFieldStyle(GlassTextFieldStyle())
                                .frame(width: 130)
                                .multilineTextAlignment(.center)
                            
                            HStack(spacing: 24) {
                                Button(action: { withAnimation { isEditing = false } }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white.opacity(0.8))
                                        .frame(width: 46, height: 46)
                                        .liquidGlassPill(cornerRadius: 23)
                                }
                                
                                Button(action: saveChanges) {
                                    Group {
                                        if isSaving {
                                            ProgressView().tint(.black)
                                        } else {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.black)
                                        }
                                    }
                                    .frame(width: 46, height: 46)
                                    .liquidGlassGoldButton(cornerRadius: 23)
                                }
                                .disabled(isSaving)
                            }
                            .padding(.top, 4)
                        }
                        .padding(18)
                    } else {
                        VStack(spacing: 8) {
                            Text(item.category.rawValue.uppercased())
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(Color.luxeEcru)
                                .tracking(2)
                            
                            Text(item.subCategory.uppercased())
                                .font(.system(size: 22, weight: .bold, design: .serif))
                                .foregroundColor(.luxeFlax)
                                .tracking(2)
                            
                            if !item.size.isEmpty {
                                Text("SIZE \(item.size.uppercased())")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.luxeBeige)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .liquidGlassPill(cornerRadius: 10)
                                    .padding(.top, 4)
                            }
                            
                            if isOwner {
                                Button(action: {
                                    editedCategory = item.category
                                    editedSubCategory = item.subCategory
                                    editedSize = item.size
                                    withAnimation { isEditing = true }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "pencil")
                                        Text("Edit Details")
                                    }
                                    .font(.caption.bold())
                                    .foregroundColor(.luxeFlax)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .liquidGlassPill(cornerRadius: 10)
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding(20)
                    }
                }
                .liquidGlassCard(cornerRadius: 22)
                .padding(.horizontal, 24)
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.luxeBeige)
                            .frame(width: 40, height: 40)
                            .liquidGlassPill(cornerRadius: 20)
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 50)
                }
                Spacer()
            }
        }
    }
    
    func saveChanges() {
        isSaving = true
        Task {
            await viewModel.updateItemDetails(
                item: item,
                newCategory: editedCategory,
                newSubCategory: editedSubCategory,
                newSize: editedSize
            )
            await MainActor.run {
                withAnimation {
                    isEditing = false
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - History Views
struct HistorySheetView: View {
    @ObservedObject var viewModel: ClosetViewModel
    @Binding var isPresented: Bool
    @State private var selectedLook: SavedLook?
    
    let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 15)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidGlassBackgroundView()
                ScrollView {
                    if viewModel.savedLooks.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "photo.stack")
                                .font(.system(size: 48, weight: .light))
                                .foregroundStyle(Color.luxeGoldGradient)
                            Text("No Saved Looks Yet")
                                .font(.system(size: 18, weight: .bold, design: .serif))
                                .foregroundColor(.luxeBeige)
                            Text("Generate try-on combinations in your closet and save your favorite outfits here.")
                                .font(.subheadline)
                                .foregroundColor(.luxeBeige.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(.vertical, 40)
                        .padding(.horizontal, 20)
                        .liquidGlassCard(cornerRadius: 20)
                        .padding(.horizontal, 20)
                        .padding(.top, 80)
                    } else {
                        LazyVGrid(columns: columns, spacing: 15) {
                            ForEach(viewModel.savedLooks) { look in
                                ZStack(alignment: .topTrailing) {
                                    KFImage(URL(string: look.imageURL))
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 180)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [.white.opacity(0.4), Color.luxeEcru.opacity(0.2), .white.opacity(0.05)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                                        .contentShape(Rectangle())
                                        .onTapGesture { selectedLook = look }
                                    
                                    Menu {
                                        Button("Restore", systemImage: "arrow.counterclockwise") {
                                            Task {
                                                await viewModel.restoreLook(look)
                                                isPresented = false
                                            }
                                        }
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            viewModel.deleteLook(look)
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .font(.subheadline.bold())
                                            .foregroundColor(.black)
                                            .padding(8)
                                            .liquidGlassGoldButton(cornerRadius: 16)
                                    }
                                    .padding(8)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Look History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                        .foregroundColor(.luxeFlax)
                }
            }
            .fullScreenCover(item: $selectedLook) { look in
                HistoryZoomView(
                    look: look,
                    viewModel: viewModel,
                    parentSheetPresented: $isPresented,
                    onDismiss: { selectedLook = nil }
                )
            }
        }
    }
}

struct HistoryZoomView: View {
    let look: SavedLook
    @ObservedObject var viewModel: ClosetViewModel
    @Binding var parentSheetPresented: Bool
    var onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            LiquidGlassBackgroundView()
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.85))
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            KFImage(URL(string: look.imageURL))
                .resizable()
                .scaledToFit()
                .padding()
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.luxeBeige)
                            .frame(width: 40, height: 40)
                            .liquidGlassPill(cornerRadius: 20)
                            .padding(.top, 50)
                            .padding(.trailing, 20)
                    }
                }
                Spacer()
                HStack(spacing: 16) {
                    Button(action: {
                        viewModel.deleteLook(look)
                        onDismiss()
                    }) {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 70, height: 60)
                            .liquidGlassPill(cornerRadius: 14)
                    }
                    Button(action: {
                        Task {
                            await viewModel.restoreLook(look)
                            onDismiss()
                            parentSheetPresented = false
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Restore")
                        }
                        .font(.headline.bold())
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .liquidGlassGoldButton(cornerRadius: 14)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 50)
            }
        }
    }
}

// MARK: - Helper Views & Shapes
struct RoundedCorner: Shape { var radius: CGFloat = .infinity; var corners: UIRectCorner = .allCorners; func path(in rect: CGRect) -> Path { let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius)); return Path(path.cgPath) } }
extension View { func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View { clipShape(RoundedCorner(radius: radius, corners: corners)) } }

struct GlassTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .foregroundColor(.white)
    }
}
