//
//  SmartAddItemSheet.swift
//  fitpick
//
//  Created by FitPick AI on 2/4/26.
//

import SwiftUI

struct SmartAddItemSheet: View {
    @Environment(\.presentationMode) var presentationMode
    
    // MVVM: The View owns the ViewModel
    @StateObject private var vm: SmartAddItemViewModel
    
    // Custom Init to inject the dependency
    init(viewModel: ClosetViewModel) {
        _vm = StateObject(wrappedValue: SmartAddItemViewModel(closetVM: viewModel))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                
                if vm.step == 1 {
                    scanStepView
                } else if vm.step == 2 {
                    reviewStepView
                }
            }
            .navigationTitle(vm.step == 1 ? "Scan Item" : "Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .alert("Invalid Scan", isPresented: $vm.showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(vm.errorMessage)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var scanStepView: some View {
        VStack {
            // Camera Area
            ZStack(alignment: .bottom) {
                if let img = vm.capturedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .shadow(radius: 5)
                } else {
                    AutoMeasureCameraView(
                        measuredWidth: $vm.measuredWidth,
                        measuredLength: $vm.measuredLength,
                        capturedImage: $vm.capturedImage,
                        isScanning: $vm.isScanning
                    )
                    .cornerRadius(12)
                    
                    // Overlay Guide
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
            if vm.isScanning {
                VStack {
                    ProgressView()
                    Text("Analyzing...").font(.caption).foregroundColor(.secondary)
                }
            } else if vm.capturedImage == nil {
                Button(action: { vm.isScanning = true }) {
                    VStack {
                        Image(systemName: "circle.inset.filled")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                        Text("Tap to Scan").font(.caption).foregroundColor(.gray)
                    }
                }
            } else {
                // Post-Capture Controls
                HStack(spacing: 40) {
                    MeasurementBadge(title: "Width", value: vm.measuredWidth)
                    MeasurementBadge(title: "Length", value: vm.measuredLength)
                }
                
                HStack(spacing: 20) {
                    Button("Retake") {
                        vm.resetScan()
                    }
                    .foregroundColor(.red)
                    
                    Button("Next: AI Sizing") {
                        vm.step = 2
                        vm.performAIAnalysis()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 10)
            }
        }
    }
    
    private var reviewStepView: some View {
        Form {
            Section("Image") {
                if let img = vm.capturedImage {
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
            
            Section("Item Details (Required for Sizing)") {
                Picker("Category", selection: $vm.category) {
                    Text("Top").tag("Top")
                    Text("Bottom").tag("Bottom")
                    Text("Shoes").tag("Shoes")
                    Text("Accessories").tag("Accessories")
                }
                // FIX: Updated to iOS 17 syntax (2 parameters: oldValue, newValue)
                .onChange(of: vm.category) { _, _ in
                    vm.performAIAnalysis()
                }
                
                HStack {
                    Text("Sub-Category")
                    Spacer()
                    TextField("e.g. T-Shirt", text: $vm.subCategory)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            Section("LiDAR Data (Read-Only)") {
                HStack {
                    Text("Width")
                    Spacer()
                    Text(String(format: "%.1f inches", vm.measuredWidth ?? 0))
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Length")
                    Spacer()
                    Text(String(format: "%.1f inches", vm.measuredLength ?? 0))
                        .foregroundColor(.secondary)
                }
            }
            
            Section("AI Recommended Size") {
                if vm.isAnalyzingAI {
                    HStack { Text("Calculating..."); Spacer(); ProgressView() }
                } else {
                    HStack {
                        Text("Estimated Size")
                        Spacer()
                        // Read-Only Text
                        Text(vm.size)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .foregroundColor(.blue)
                            .bold()
                    }
                    Text("Based on standard US sizing charts using your LiDAR measurements.")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Button(action: {
                vm.saveSmartItem {
                    // On Success: Dismiss
                    presentationMode.wrappedValue.dismiss()
                }
            }) {
                if vm.closetVM.isUploading || vm.isValidating {
                    HStack {
                        Text(vm.isValidating ? "Validating Image..." : "Saving...")
                        Spacer()
                        ProgressView()
                    }
                } else {
                    Text("Save to Closet")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(.blue)
                }
            }
            .disabled(vm.isAnalyzingAI || vm.closetVM.isUploading || vm.isValidating)
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
