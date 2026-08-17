//
//  BulkAddItemViewModel.swift
//  fitpick
//
//  Created by FitPick AI on 2/13/26.
//

import SwiftUI
import PhotosUI
import Combine

@MainActor
class BulkAddItemViewModel: ObservableObject {
    
    // MARK: - Dependencies
    let closetVM: ClosetViewModel
    
    // MARK: - UI State
    @Published var draftItems: [DraftItem] = []
    @Published var isLoadingImages = false
    @Published var isAutoCategorizingAll = false
    @Published var isSaving = false
    @Published var saveProgress: Int = 0
    
    init(closetVM: ClosetViewModel) {
        self.closetVM = closetVM
    }
    
    // MARK: - 1. Load & Validate
    func loadImages(from pickerItems: [PhotosPickerItem]) {
        self.isLoadingImages = true
        self.draftItems = [] // Reset
        
        Task {
            var newItems: [DraftItem] = []
            
            for item in pickerItems {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    
                    // Create DraftItem (Definition is in ClothingItem.swift)
                    let draft = DraftItem(image: uiImage)
                    newItems.append(draft)
                }
            }
            
            self.draftItems = newItems
            self.isLoadingImages = false
            
            // Auto-start validation and AI categorization
            await validateAllItems()
            await autoCategorizeAllItems()
        }
    }
    
    /// Runs AI Validation (Trees/Cars check)
    private func validateAllItems() async {
        for index in draftItems.indices {
            draftItems[index].isValidating = true
            
            // Uses the shared validation logic from ClosetViewModel
            let isCloth = await closetVM.validateImageIsClothing(draftItems[index].image)
            
            draftItems[index].isValidating = false
            draftItems[index].isClothing = isCloth
            draftItems[index].validationMessage = isCloth ? "Valid" : "Not a clothing item"
        }
    }
    
    /// Runs AI Auto-Categorization across all valid clothing/accessory items
    func autoCategorizeAllItems() async {
        isAutoCategorizingAll = true
        for index in draftItems.indices {
            guard draftItems[index].isClothing else { continue }
            draftItems[index].isCategorizing = true
            if let result = await closetVM.autoCategorizeClothing(image: draftItems[index].image) {
                draftItems[index].category = result.category
                draftItems[index].subCategory = result.subcategory
                if draftItems[index].size.isEmpty && result.category == .accessories {
                    draftItems[index].size = "One Size"
                }
            }
            draftItems[index].isCategorizing = false
        }
        isAutoCategorizingAll = false
    }

    /// Auto-categorizes a single draft item
    func autoCategorizeItem(id: UUID) {
        guard let index = draftItems.firstIndex(where: { $0.id == id }) else { return }
        draftItems[index].isCategorizing = true
        Task {
            if let result = await closetVM.autoCategorizeClothing(image: draftItems[index].image) {
                if let i = draftItems.firstIndex(where: { $0.id == id }) {
                    draftItems[i].category = result.category
                    draftItems[i].subCategory = result.subcategory
                    if draftItems[i].size.isEmpty && result.category == .accessories {
                        draftItems[i].size = "One Size"
                    }
                }
            }
            if let i = draftItems.firstIndex(where: { $0.id == id }) {
                draftItems[i].isCategorizing = false
            }
        }
    }
    
    // MARK: - 2. Batch Save
    func saveAllValidItems(onComplete: @escaping () -> Void) {
        let validItems = draftItems.filter { $0.isClothing }
        guard !validItems.isEmpty else { return }
        
        isSaving = true
        saveProgress = 0
        
        Task {
            await withTaskGroup(of: Void.self) { group in
                for item in validItems {
                    group.addTask {
                        await self.closetVM.saveManualItem(
                            image: item.image,
                            category: item.category,
                            subCategory: item.subCategory.isEmpty ? "Other" : item.subCategory,
                            size: item.size.isEmpty ? "Unknown" : item.size
                        )
                    }
                }
                
                // Track progress
                for await _ in group {
                    await MainActor.run { self.saveProgress += 1 }
                }
            }
            
            isSaving = false
            onComplete()
        }
    }
    
    // MARK: - Helpers
    func removeDraft(id: UUID) {
        draftItems.removeAll { $0.id == id }
    }
    
    func applyCategoryToAll(_ category: ClothingCategory) {
        for i in draftItems.indices {
            draftItems[i].category = category
        }
    }
}
