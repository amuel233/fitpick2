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
                LiquidGlassBackgroundView()
                
                VStack {
                    if vm.isLoadingImages {
                        VStack(spacing: 16) {
                            ProgressView().tint(Color.luxeFlax).scaleEffect(1.3)
                            Text("Processing Photos...")
                                .foregroundColor(.luxeFlax)
                                .font(.caption.bold())
                        }
                        .padding(32)
                        .liquidGlassCard(cornerRadius: 20)
                        .padding(.top, 80)
                    } else if vm.draftItems.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 48, weight: .light))
                                .foregroundStyle(Color.luxeGoldGradient)
                            Text("No Images Selected")
                                .font(.system(size: 18, weight: .bold, design: .serif))
                                .foregroundColor(.luxeBeige)
                            Text("Try selecting clothing photos from your library again.")
                                .font(.subheadline)
                                .foregroundColor(.luxeBeige.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                        .padding(32)
                        .liquidGlassCard(cornerRadius: 20)
                        .padding(.horizontal, 24)
                        .padding(.top, 60)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach($vm.draftItems) { $item in
                                    BulkItemRow(
                                        item: $item,
                                        onAutoCategorize: { vm.autoCategorizeItem(id: item.id) },
                                        onDelete: { withAnimation { vm.removeDraft(id: item.id) } }
                                    )
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
                            .liquidGlassGoldButton(cornerRadius: 14)
                        } else {
                            Button(action: {
                                vm.saveAllValidItems { presentationMode.wrappedValue.dismiss() }
                            }) {
                                Text("Save Valid Items (\(vm.draftItems.filter { $0.isClothing }.count))")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 55)
                                    .liquidGlassGoldButton(cornerRadius: 16)
                            }
                            .disabled(vm.draftItems.filter { $0.isClothing }.isEmpty)
                        }
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: Color.luxeBlack.opacity(0.85), location: 0.4),
                                .init(color: Color.luxeBlack, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .navigationTitle("Review Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(.luxeFlax)
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 10) {
                        Button(action: {
                            Task { await vm.autoCategorizeAllItems() }
                        }) {
                            HStack(spacing: 4) {
                                if vm.isAutoCategorizingAll {
                                    ProgressView().tint(.black).scaleEffect(0.7)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text("Auto-Categorize")
                            }
                            .font(.caption.bold())
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .liquidGlassGoldButton(cornerRadius: 8)
                        }
                        .disabled(vm.isAutoCategorizingAll)
                        
                        Menu {
                            Button("Set All to Tops") { withAnimation { vm.applyCategoryToAll(.top) } }
                            Button("Set All to Bottoms") { withAnimation { vm.applyCategoryToAll(.bottom) } }
                            Button("Set All to Shoes") { withAnimation { vm.applyCategoryToAll(.shoes) } }
                            Button("Set All to Accessories") { withAnimation { vm.applyCategoryToAll(.accessories) } }
                        } label: {
                            Text("Quick Set")
                                .font(.caption.bold())
                                .foregroundColor(.luxeBeige)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .liquidGlassPill(cornerRadius: 8)
                        }
                    }
                }
            }
        }
    }
}

struct BulkItemRow: View {
    @Binding var item: DraftItem
    var onAutoCategorize: () -> Void
    var onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(uiImage: item.image)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            item.isClothing ? LinearGradient(colors: [.white.opacity(0.4), Color.luxeEcru.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing),
                            lineWidth: item.isClothing ? 1 : 2
                        )
                )
            
            VStack(alignment: .leading, spacing: 10) {
                if item.isValidating {
                    Text("Validating...").font(.caption).foregroundColor(.luxeEcru)
                } else if item.isCategorizing {
                    HStack(spacing: 4) {
                        ProgressView().tint(Color.luxeFlax).scaleEffect(0.7)
                        Text("Auto-categorizing...").font(.caption).foregroundColor(.luxeFlax)
                    }
                } else if !item.isClothing {
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
                        HStack(spacing: 4) {
                            Text(item.category.rawValue)
                            Image(systemName: "chevron.down").font(.caption2)
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.luxeBeige)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .liquidGlassPill(cornerRadius: 8)
                    }
                    
                    Button(action: onAutoCategorize) {
                        HStack(spacing: 3) {
                            if item.isCategorizing {
                                ProgressView().tint(Color.luxeFlax).scaleEffect(0.6)
                            } else {
                                Image(systemName: "sparkles")
                                Text("Auto")
                            }
                        }
                        .font(.caption2.bold())
                        .foregroundColor(.luxeFlax)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .liquidGlassPill(cornerRadius: 8)
                    }
                    .disabled(item.isCategorizing)
                    
                    Spacer()
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundColor(.red.opacity(0.85))
                            .frame(width: 30, height: 30)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.red.opacity(0.3), lineWidth: 0.8))
                    }
                }
                
                HStack(spacing: 8) {
                    LuxeTextField(placeholder: "Type (e.g. Jeans, Sunglasses)", text: $item.subCategory)
                    LuxeTextField(placeholder: "Size", text: $item.size).frame(width: 70)
                }
            }
        }
        .padding(12)
        .liquidGlassCard(cornerRadius: 16)
        .opacity(item.isClothing ? 1.0 : 0.6)
    }
}

struct LuxeTextField: View {
    let placeholder: String
    @Binding var text: String
    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.gray))
            .font(.caption)
            .foregroundColor(.white)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
    }
}
