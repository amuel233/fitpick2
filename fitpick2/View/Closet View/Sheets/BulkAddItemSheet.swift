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
    @StateObject private var vm: BulkAddItemViewModel
    
    init(viewModel: ClosetViewModel, pickerItems: [PhotosPickerItem]) {
        let bulkVM = BulkAddItemViewModel(closetVM: viewModel)
        _vm = StateObject(wrappedValue: bulkVM)
        bulkVM.loadImages(from: pickerItems)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.luxeSpotlightGradient.ignoresSafeArea()
                
                VStack {
                    if vm.isLoadingImages {
                        VStack(spacing: 15) {
                            ProgressView().tint(Color.luxeEcru).scaleEffect(1.5)
                            Text("Processing Photos...").foregroundColor(.luxeEcru).font(.caption)
                        }
                    } else if vm.draftItems.isEmpty {
                        ContentUnavailableView {
                            Label("No Images", systemImage: "photo.on.rectangle.angled")
                        } description: {
                            Text("Try selecting images again.").foregroundColor(.gray)
                        }
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
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if !vm.draftItems.isEmpty {
                    VStack(spacing: 10) {
                        if vm.isSaving {
                            HStack {
                                ProgressView().tint(.black)
                                Text("Saving \(vm.saveProgress) of \(vm.draftItems.filter({$0.isClothing}).count)...")
                                    .fontWeight(.bold).foregroundColor(.black)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.luxeFlax)
                            .cornerRadius(12)
                        } else {
                            Button(action: {
                                vm.saveAllValidItems { presentationMode.wrappedValue.dismiss() }
                            }) {
                                Text("Save Valid Items (\(vm.draftItems.filter { $0.isClothing }.count))")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 55)
                                    .background(Color.luxeGoldGradient)
                                    .foregroundColor(.black)
                                    .cornerRadius(16)
                                    .shadow(color: Color.luxeEcru.opacity(0.4), radius: 10, y: 5)
                            }
                            .disabled(vm.draftItems.filter { $0.isClothing }.isEmpty)
                        }
                    }
                    .padding()
                    .background(LinearGradient(colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom))
                }
            }
            .navigationTitle("Review Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }.foregroundColor(.luxeEcru)
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Set All to Tops") { withAnimation { vm.applyCategoryToAll(.top) } }
                        Button("Set All to Bottoms") { withAnimation { vm.applyCategoryToAll(.bottom) } }
                        Button("Set All to Shoes") { withAnimation { vm.applyCategoryToAll(.shoes) } }
                    } label: { Text("Quick Set").foregroundColor(.luxeFlax) }
                }
            }
        }
    }
}

struct BulkItemRow: View {
    @Binding var item: DraftItem
    var onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(uiImage: item.image)
                .resizable().scaledToFill().frame(width: 80, height: 80).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(item.isClothing ? Color.luxeEcru.opacity(0.5) : Color.red, lineWidth: item.isClothing ? 1 : 2))
            
            VStack(alignment: .leading, spacing: 10) {
                if item.isValidating {
                    Text("Validating...").font(.caption).foregroundColor(.luxeEcru)
                } else if !item.isClothing {
                    // ✅ FIXED: Changed Label to Button to allow manual override
                    Button(action: {
                        withAnimation { item.isClothing = true }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("Not clothing (Tap to Keep)")
                        }
                        .font(.caption.bold())
                        .foregroundColor(.red)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
                
                HStack {
                    Menu {
                        ForEach(ClothingCategory.allCases, id: \.self) { cat in Button(cat.rawValue) { item.category = cat } }
                    } label: {
                        HStack { Text(item.category.rawValue); Image(systemName: "chevron.down").font(.caption) }
                        .font(.subheadline.bold()).foregroundColor(.luxeBeige).padding(.horizontal, 10).padding(.vertical, 5).background(Color.white.opacity(0.1)).cornerRadius(8)
                    }
                    Spacer()
                    Button(action: onDelete) { Image(systemName: "trash").foregroundColor(.red.opacity(0.8)) }
                }
                
                HStack(spacing: 8) {
                    LuxeTextField(placeholder: "Type (e.g. Jeans)", text: $item.subCategory)
                    LuxeTextField(placeholder: "Size", text: $item.size).frame(width: 70)
                }
            }
        }
        .padding(12).background(.ultraThinMaterial).environment(\.colorScheme, .dark).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
        // Opacity reflects validity; if manually overridden to true, it becomes fully opaque (1.0)
        .opacity(item.isClothing ? 1.0 : 0.6)
    }
}

struct LuxeTextField: View {
    let placeholder: String
    @Binding var text: String
    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.gray))
            .font(.caption).foregroundColor(.white).padding(8).background(Color.black.opacity(0.3)).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
