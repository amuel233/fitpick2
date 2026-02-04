//
//  AddItemSheet.swift
//  fitpick
//
//  Created by FitPick on 2/4/26.
//

import SwiftUI

struct AddItemSheet: View {
    @Environment(\.dismiss) var dismiss
    
    // 1. Accepts the image passed from ClosetView (Gallery Picker)
    let image: UIImage
    
    @ObservedObject var viewModel: ClosetViewModel
    
    // Form State (Manual Entry Only)
    @State private var category: ClothingCategory = .top
    @State private var subCategory: String = ""
    @State private var size: String = ""
    
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
                
                // Section 3: Save Button
                Section {
                    Button(action: saveItem) {
                        if viewModel.isUploading {
                            HStack {
                                Text("Saving...")
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
                }
                .disabled(viewModel.isUploading)
            }
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Logic
    func saveItem() {
        Task {
            // Calls the manual save function in ViewModel
            await viewModel.saveManualItem(
                image: image,
                category: category,
                subCategory: subCategory.isEmpty ? "Other" : subCategory,
                size: size.isEmpty ? "Unknown" : size
            )
            dismiss()
        }
    }
}
