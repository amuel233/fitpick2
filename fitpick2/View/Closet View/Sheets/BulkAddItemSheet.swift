//
//  BulkAddItemSheet.swift
//  fitpick
//
//  Created by FitPick on 2/13/26.
//

import SwiftUI
import PhotosUI

struct BulkAddItemSheet: View {
    @Environment(\.presentationMode) var presentationMode
    
    // Owns the ViewModel
    @StateObject private var vm: BulkAddItemViewModel
    
    // Init: Takes photos and triggers load
    init(viewModel: ClosetViewModel, pickerItems: [PhotosPickerItem]) {
        let bulkVM = BulkAddItemViewModel(closetVM: viewModel)
        _vm = StateObject(wrappedValue: bulkVM)
        
        // Trigger load
        bulkVM.loadImages(from: pickerItems)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if vm.isLoadingImages {
                    ProgressView("Processing Photos...")
                        .scaleEffect(1.5)
                } else if vm.draftItems.isEmpty {
                    ContentUnavailableView("No Images Loaded", systemImage: "photo.on.rectangle.angled")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach($vm.draftItems) { $item in
                                BulkItemRow(item: $item) {
                                    withAnimation { vm.removeDraft(id: item.id) }
                                }
                            }
                        }
                        .padding()
                        .padding(.bottom, 80)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if !vm.draftItems.isEmpty {
                    VStack(spacing: 10) {
                        if vm.isSaving {
                            HStack {
                                ProgressView()
                                Text("Saving \(vm.saveProgress) of \(vm.draftItems.filter({$0.isClothing}).count)...")
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                        } else {
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
                            .disabled(vm.draftItems.filter { $0.isClothing }.isEmpty)
                        }
                    }
                    .padding()
                    .background(LinearGradient(colors: [.white.opacity(0), .white], startPoint: .top, endPoint: .bottom))
                }
            }
            .navigationTitle("Review Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
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

// MARK: - Row Component
struct BulkItemRow: View {
    @Binding var item: DraftItem
    var onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Thumbnail
            Image(uiImage: item.image)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(item.isClothing ? Color.clear : Color.red, lineWidth: 3)
                )
            
            // Fields
            VStack(alignment: .leading, spacing: 8) {
                if item.isValidating {
                    Text("Validating...").font(.caption).foregroundColor(.gray)
                } else if !item.isClothing {
                    Label("Not clothing detected", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundColor(.red).bold()
                }
                
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
        .opacity(item.isClothing ? 1.0 : 0.6)
    }
}
