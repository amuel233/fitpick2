//
//  SmartAddItemViewModel.swift
//  fitpick
//
//  Created by Bry on 2/13/26.
//

import SwiftUI
import Combine

@MainActor // Ensures all UI updates happen on the main thread
class SmartAddItemViewModel: ObservableObject {
    
    // MARK: - Dependencies
    // We keep a reference to ClosetViewModel to access shared functions (Save, Validate, etc.)
    let closetVM: ClosetViewModel
    
    // MARK: - Flow State
    @Published var step = 1 // 1: Scan, 2: Review/Calc
    
    // MARK: - Item Data
    @Published var category = "Top"
    @Published var subCategory = "T-Shirt"
    @Published var size = "Calculating..."
    
    // MARK: - Camera / LiDAR Data
    @Published var measuredWidth: Double?
    @Published var measuredLength: Double?
    @Published var capturedImage: UIImage?
    @Published var isScanning = false
    
    // MARK: - Loading & Validation State
    @Published var isAnalyzingAI = false
    @Published var isValidating = false
    @Published var showingErrorAlert = false
    @Published var errorMessage = ""
    
    // MARK: - Init
    init(closetVM: ClosetViewModel) {
        self.closetVM = closetVM
    }
    
    // MARK: - Logic Methods
    
    func performAIAnalysis() {
        guard capturedImage != nil else { return }
        isAnalyzingAI = true
        
        Task {
            if let w = measuredWidth, let l = measuredLength {
                let estimatedSize = await closetVM.determineSizeFromAutoMeasurements(
                    width: w,
                    length: l,
                    category: category,
                    subCategory: subCategory
                )
                self.size = estimatedSize
                self.isAnalyzingAI = false
            } else {
                self.isAnalyzingAI = false
            }
        }
    }
    
    func saveSmartItem(onSuccess: @escaping () -> Void) {
        guard let img = capturedImage, let w = measuredWidth, let l = measuredLength else { return }
        
        Task {
            // 1. Validation Step
            isValidating = true
            let isValid = await closetVM.validateImageIsClothing(img)
            
            if !isValid {
                isValidating = false
                errorMessage = "This image does not appear to be a clothing item. Please scan a Top, Bottom, or Shoes."
                showingErrorAlert = true
                return
            }
            
            // 2. Save Step
            await closetVM.saveAutoMeasuredItem(
                image: img,
                category: category,
                subCategory: subCategory,
                size: size,
                width: w,
                length: l
            )
            
            isValidating = false
            onSuccess() // Trigger dismissal
        }
    }
    
    func resetScan() {
        capturedImage = nil
        measuredWidth = nil
        measuredLength = nil
        step = 1
    }
}
