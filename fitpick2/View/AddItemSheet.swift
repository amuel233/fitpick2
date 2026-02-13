//
//  AddItemSheet.swift
//  fitpick
//
//  Created by FitPick on 2/4/26.
//

import SwiftUI

struct AddItemSheet: View {
    // FIX: Use presentationMode to avoid "Binding<Subject>" errors
    @Environment(\.presentationMode) var presentationMode
    
    // 1. Accepts the image passed from ClosetView (Gallery Picker)
    let image: UIImage
    
    @ObservedObject var viewModel: ClosetViewModel
    
    // Form State (Manual Entry)
    @State private var category: ClothingCategory = .top
    @State private var subCategory: String = ""
    @State private var size: String = ""
    
    // Validation State
    @State private var isValidating = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Image Preview
                Section {
                    HStack {
                        Spacer()
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 250)
                            .cornerRadius(12)
                            .shadow(radius: 5)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
                
                // Section 2: Details (Manual Input)
                Section("Item Details") {
                    Picker("Category", selection: $category) {
                        ForEach(ClothingCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    HStack {
                        Text("Type")
                        Spacer()
                        TextField("e.g. Bomber Jacket", text: $subCategory)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Size")
                        Spacer()
                        TextField("e.g. M, 32, US 10", text: $size)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                // Section 3: Save Button (With Validation Logic)
                Section {
                    Button(action: saveItem) {
                        if viewModel.isUploading || isValidating {
                            HStack {
                                Text(isValidating ? "Validating Image..." : "Saving...")
                                Spacer()
                                ProgressView()
                            }
                        } else {
                            Text("Add to Closet")
                                .frame(maxWidth: .infinity)
                                .bold()
                                .foregroundColor(.white)
                        }
                    }
                    .listRowBackground(Color.blue)
                    .disabled(viewModel.isUploading || isValidating)
                }
            }
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
            }
            // Alert for Invalid Images (e.g. Cars, Food)
            .alert("Invalid Image", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Logic
    func saveItem() {
        Task {
            // 1. Start Validation
            isValidating = true
            
            // Check if image is actually clothing (Prevents Hallucinations)
            // Note: Ensure 'validateImageIsClothing' is in your ClosetViewModel
            let isValid = await viewModel.validateImageIsClothing(image)
            
            if !isValid {
                // STOP: It's a car, food, etc.
                isValidating = false
                errorMessage = "This image does not appear to be a clothing item. Please upload a clear photo of a Top, Bottom, or Shoes."
                showingErrorAlert = true
                return
            }
            
            // 2. Proceed to Save
            await viewModel.saveManualItem(
                image: image,
                category: category,
                subCategory: subCategory.isEmpty ? "Other" : subCategory,
                size: size.isEmpty ? "Unknown" : size
            )
            
            isValidating = false
            presentationMode.wrappedValue.dismiss()
        }
    }
}
