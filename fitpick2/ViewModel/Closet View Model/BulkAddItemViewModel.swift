//
//  BulkAddItemViewModel.swift
//  fitpick2
//
//  Created by Bryan Gavino on 2/13/26.
//
//

import SwiftUI
import PhotosUI
import Combine

// MARK: - Draft Item Model
// Represents a single photo in the bulk upload list
struct DraftItem: Identifiable {
    let id = UUID()
    let image: UIImage
    
    // Editable Fields
    var category: ClothingCategory = .top
    var subCategory: String = ""
    var size: String = ""
    
    // Validation State (Anti-Hallucination)
    var isValidating: Bool = true
    var isClothing: Bool = false
    var validationMessage: String = "Checking..."
}

@MainActor
class BulkAddItemViewModel: ObservableObject {
    
    // MARK: - Dependencies
    // We reuse the main ViewModel to access the save function and validation logic
    let closetVM: ClosetViewModel
    
    // MARK: - UI State
    @Published var draftItems: [DraftItem] = []
    @Published var isLoadingImages = false // Spinner while converting picker items to images
    @Published var isSaving = false        // Spinner while uploading to Firebase
    @Published var saveProgress: Int = 0   // Progress counter (e.g., "1/5 saved")
    
    init(closetVM: ClosetViewModel) {
        self.closetVM = closetVM
    }
    
    // MARK: - 1. Load & Validate
    
    /// Converts PhotosPickerItems to UIImages and starts AI validation
    func loadImages(from pickerItems: [PhotosPickerItem]) {
        self.isLoadingImages = true
        self.draftItems = [] // Reset list
        
        Task {
            var newItems: [DraftItem] = []
            
            // CONVERSION LOOP: Turn picker selections into data
            for item in pickerItems {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    
                    let draft = DraftItem(image: uiImage)
                    newItems.append(draft)
                }
            }
            
            // Update UI with the raw images first
            self.draftItems = newItems
            self.isLoadingImages = false
            
            // VALIDATION LOOP: Check each image in background
            await validateAllItems()
        }
    }
    
    /// Runs Apple Vision on every item to check for cars/food/etc.
    private func validateAllItems() async {
        for index in draftItems.indices {
            // Update UI to show "Validating..."
            draftItems[index].isValidating = true
            
            // Call the validation function from ClosetViewModel
            let isCloth = await closetVM.validateImageIsClothing(draftItems[index].image)
            
            // Update the item with the result
            draftItems[index].isValidating = false
            draftItems[index].isClothing = isCloth
            draftItems[index].validationMessage = isCloth ? "Valid" : "Not a clothing item"
        }
    }
    
    // MARK: - 2. Batch Save
    
    /// Saves all items that passed validation to Firestore
    func saveAllValidItems(onComplete: @escaping () -> Void) {
        // Filter: Ignore cars/trash
        let validItems = draftItems.filter { $0.isClothing }
        guard !validItems.isEmpty else { return }
        
        isSaving = true
        saveProgress = 0
        
        Task {
            // PARALLEL UPLOAD: Use TaskGroup to upload everything at once
            await withTaskGroup(of: Void.self) { group in
                for item in validItems {
                    group.addTask {
                        // Reuse the existing single-save logic
                        await self.closetVM.saveManualItem(
                            image: item.image,
                            category: item.category,
                            subCategory: item.subCategory.isEmpty ? "Other" : item.subCategory,
                            size: item.size.isEmpty ? "Unknown" : item.size
                        )
                    }
                }
                
                // Track completion for the progress bar
                for await _ in group {
                    await MainActor.run {
                        self.saveProgress += 1
                    }
                }
            }
            
            // Finished
            isSaving = false
            onComplete()
        }
    }
    
    // MARK: - Helpers
    
    func removeDraft(id: UUID) {
        draftItems.removeAll { $0.id == id }
    }
    
    /// "Quick Set" feature to categorize everything at once
    func applyCategoryToAll(_ category: ClothingCategory) {
        for i in draftItems.indices {
            draftItems[i].category = category
        }
    }
}
