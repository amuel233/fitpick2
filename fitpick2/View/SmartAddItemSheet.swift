//
//  SmartAddItemSheet.swift
//  fitpick
//
//  Created by FitPick AI on 2/4/26.
//

import SwiftUI

struct SmartAddItemSheet: View {
    // FIX: Use presentationMode to avoid "Binding<Subject>" errors
    @Environment(\.presentationMode) var presentationMode
    
    // ViewModel to handle AI and Saving
    @ObservedObject var viewModel: ClosetViewModel
    
    // Flow State
    @State private var step = 1 // 1: Scan, 2: Review/Calc, 3: Save
    @State private var category = "Top"
    @State private var subCategory = "T-Shirt"
    @State private var size = "Calculating..."
    
    // Auto-Measure State (Populated by the Camera View)
    @State private var measuredWidth: Double?
    @State private var measuredLength: Double?
    @State private var capturedImage: UIImage?
    @State private var isScanning = false
    @State private var isAnalyzingAI = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                
                if step == 1 {
                    // MARK: STEP 1 - LIVE CAMERA SCAN
                    ZStack(alignment: .bottom) {
                        if let img = capturedImage {
                            // Show captured snapshot
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(12)
                                .shadow(radius: 5)
                        } else {
                            // --- HERE IS THE FIX ---
                            // We replaced the placeholder Text with your actual Camera View
                            AutoMeasureCameraView(
                                measuredWidth: $measuredWidth,
                                measuredLength: $measuredLength,
                                capturedImage: $capturedImage,
                                isScanning: $isScanning
                            )
                            .cornerRadius(12)
                            // -----------------------
                            
                            // Guide Overlay
                            VStack {
                                Text("Place item on flat surface")
                                    .font(.caption)
                                    .padding(8)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(8)
                                    .padding(.top, 10)
                                Spacer()
                                Image(systemName: "viewfinder")
                                    .font(.system(size: 100, weight: .thin))
                                    .foregroundColor(.white.opacity(0.5))
                                Spacer()
                            }
                        }
                    }
                    .frame(height: 450)
                    .padding()
                    
                    // Controls
                    if isScanning {
                        VStack {
                            ProgressView()
                            Text("Analyzing...").font(.caption).foregroundColor(.secondary)
                        }
                    } else if capturedImage == nil {
                        // Start Scan Button
                        Button(action: {
                            isScanning = true
                        }) {
                            VStack {
                                Image(systemName: "circle.inset.filled")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white)
                                    .shadow(radius: 4)
                                Text("Tap to Scan").font(.caption).foregroundColor(.gray)
                            }
                        }
                    } else {
                        // Review Scan
                        HStack(spacing: 40) {
                            MeasurementBadge(title: "Width", value: measuredWidth)
                            MeasurementBadge(title: "Length", value: measuredLength)
                        }
                        
                        HStack(spacing: 20) {
                            Button("Retake") {
                                capturedImage = nil
                                measuredWidth = nil
                                measuredLength = nil
                            }
                            .foregroundColor(.red)
                            
                            Button("Next: AI Sizing") {
                                step = 2
                                performAIAnalysis()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 10)
                    }
                    
                } else if step == 2 {
                    // MARK: STEP 2 - REVIEW & SAVE
                    Form {
                        Section("Image") {
                            if let img = capturedImage {
                                HStack {
                                    Spacer()
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 150)
                                        .cornerRadius(8)
                                    Spacer()
                                }
                            }
                        }
                        
                        Section("Item Details") {
                            Picker("Category", selection: $category) {
                                Text("Top").tag("Top")
                                Text("Bottom").tag("Bottom")
                                Text("Shoes").tag("Shoes")
                                Text("Accessories").tag("Accessories")
                            }
                            
                            HStack {
                                Text("Sub-Category")
                                Spacer()
                                TextField("e.g. T-Shirt", text: $subCategory)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        
                        Section("Auto Measurements (LiDAR)") {
                            HStack { Text("Width"); Spacer(); Text(String(format: "%.1f inches", measuredWidth ?? 0)) }
                            HStack { Text("Length"); Spacer(); Text(String(format: "%.1f inches", measuredLength ?? 0)) }
                        }
                        
                        Section("AI Recommended Size") {
                            if isAnalyzingAI {
                                HStack { Text("Calculating..."); Spacer(); ProgressView() }
                            } else {
                                HStack {
                                    Text("Estimated Size")
                                    Spacer()
                                    TextField("Size", text: $size)
                                        .multilineTextAlignment(.trailing)
                                        .bold()
                                }
                                Text("Based on standard US sizing charts using your LiDAR measurements.")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Button(action: saveSmartItem) {
                            Text("Save to Closet")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(.blue)
                        }
                        .disabled(isAnalyzingAI)
                    }
                }
            }
            .navigationTitle(step == 1 ? "Scan Item" : "Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
    
    // MARK: - Logic
    func saveSmartItem() {
        Task {
            if let img = capturedImage, let w = measuredWidth, let l = measuredLength {
                await viewModel.saveAutoMeasuredItem(
                    image: img,
                    category: category,
                    subCategory: subCategory,
                    size: size,
                    width: w,
                    length: l
                )
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    func performAIAnalysis() {
        guard capturedImage != nil else { return }
        isAnalyzingAI = true
        
        Task {
            if let w = measuredWidth, let l = measuredLength {
                let estimatedSize = await viewModel.determineSizeFromAutoMeasurements(
                    width: w,
                    length: l,
                    category: category,
                    subCategory: subCategory
                )
                
                await MainActor.run {
                    self.size = estimatedSize
                    self.isAnalyzingAI = false
                }
            } else {
                await MainActor.run { self.isAnalyzingAI = false }
            }
        }
    }
}

// MARK: - Helper View
struct MeasurementBadge: View {
    let title: String
    let value: Double?
    var body: some View {
        VStack {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value != nil ? String(format: "%.1f\"", value!) : "--")
                .font(.title2.bold())
                .foregroundColor(.primary)
        }
        .frame(width: 100, height: 70)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}
