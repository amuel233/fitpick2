//
//  BulkAddItemSheet.swift
//  fitpick2
//
//  Created by Bryan Gavino on 2/13/26.
//

import SwiftUI
import PhotosUI

struct BulkAddItemSheet: View {
    @Environment(\.presentationMode) var presentationMode
    
    // Owns its own ViewModel
    @StateObject private var vm: BulkAddItemViewModel
    
    // Init: Takes the picked photos and triggers the load immediately
    init(viewModel: ClosetViewModel, pickerItems: [PhotosPickerItem]) {
        let bulkVM = BulkAddItemViewModel(closetVM: viewModel)
        _vm = StateObject(wrappedValue: bulkVM)
        
        // Trigger loading the images right when the view is created
        bulkVM.loadImages(from: pickerItems)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // STATE 1: Loading
                if vm.isLoadingImages {
                    ProgressView("Processing Photos...")
                        .scaleEffect(1.5)
                }
                // STATE 2: Empty
                else if vm.draftItems.isEmpty {
                    ContentUnavailableView("No Images Loaded", systemImage: "photo.on.rectangle.angled")
                }
                // STATE 3: List of Items
                else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Binding ($) allows editing text fields inside the row
                            ForEach($vm.draftItems) { $item in
                                BulkItemRow(item: $item) {
                                    withAnimation { vm.removeDraft(id: item.id) }
                                }
                            }
                        }
                        .padding()
                        // Add extra padding at bottom so save button doesn't cover last item
                        .padding(.bottom, 80)
                    }
                }
            }
            // MARK: - Footer (Save Button)
            .overlay(alignment: .bottom) {
                if !vm.draftItems.isEmpty {
                    VStack(spacing: 10) {
                        if vm.isSaving {
                            // Progress Indicator
                            HStack {
                                ProgressView()
                                Text("Saving \(vm.saveProgress) of \(vm.draftItems.filter({$0.isClothing}).count)...")
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                        } else {
                            // Main Action
                            Button(action: {
                                vm.saveAllValidItems {
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }) {
                                Text("Save Valid Items (\(vm.draftItems.filter { $0.isClothing }.count))")
                                    .bold()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                    .shadow(radius: 5)
                            }
                            // Disable if nothing is valid (e.g. all cars)
                            .disabled(vm.draftItems.filter { $0.isClothing }.isEmpty)
                        }
                    }
                    .padding()
                    .background(
                        LinearGradient(colors: [.white.opacity(0), .white], startPoint: .top, endPoint: .bottom)
                    )
                }
            }
            .navigationTitle("Review Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                
                // MARK: - Quick Actions Menu
                ToolbarItem(placement: .primaryAction) {
                    Menu("Quick Set") {
                        Button("Set All to Tops") { withAnimation { vm.applyCategoryToAll(.top) } }
                        Button("Set All to Bottoms") { withAnimation { vm.applyCategoryToAll(.bottom) } }
                        Button("Set All to Shoes") { withAnimation { vm.applyCategoryToAll(.shoes) } }
                    }
                }
            }
        }
    }
}

// MARK: - The Row Component
struct BulkItemRow: View {
    @Binding var item: DraftItem
    var onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 1. Thumbnail Image
            Image(uiImage: item.image)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .cornerRadius(8)
                .overlay(
                    // RED BORDER if invalid
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(item.isClothing ? Color.clear : Color.red, lineWidth: 3)
                )
            
            // 2. Form Fields
            VStack(alignment: .leading, spacing: 8) {
                
                // Status Header
                if item.isValidating {
                    Text("Validating...").font(.caption).foregroundColor(.gray)
                } else if !item.isClothing {
                    Label("Not clothing detected", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundColor(.red).bold()
                }
                
                // Category & Delete Row
                HStack {
                    Picker("Cat", selection: $item.category) {
                        ForEach(ClothingCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    .labelsHidden()
                    .frame(height: 30)
                    .clipped()
                    
                    Spacer()
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash").foregroundColor(.red.opacity(0.8))
                    }
                }
                
                // Text Inputs
                HStack {
                    TextField("Type (e.g. Jeans)", text: $item.subCategory)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    
                    TextField("Size", text: $item.size)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .frame(width: 60)
                }
            }
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        // Dim the row if it's invalid so the user focuses on the good ones
        .opacity(item.isClothing ? 1.0 : 0.6)
    }
}
