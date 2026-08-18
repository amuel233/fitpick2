//
//  SmartAddItemSheet.swift
//  fitpick
//
//  Created by FitPick AI on 2/4/26.
//

import SwiftUI

struct SmartAddItemSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var vm: SmartAddItemViewModel
    
    init(viewModel: ClosetViewModel) {
        _vm = StateObject(wrappedValue: SmartAddItemViewModel(closetVM: viewModel))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LiquidGlassBackgroundView()
                VStack(spacing: 20) { if vm.step == 1 { scanStepView } else { reviewStepView } }
            }
            .navigationTitle(vm.step == 1 ? "Scan Item" : "Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }.foregroundColor(.luxeFlax)
                }
            }
            .alert("Invalid Scan", isPresented: $vm.showingErrorAlert) { Button("OK", role: .cancel) { } } message: { Text(vm.errorMessage) }
        }
    }
    
    private var scanStepView: some View {
        VStack {
            ZStack(alignment: .bottom) {
                if let img = vm.capturedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .liquidGlassCard(cornerRadius: 18)
                } else {
                    AutoMeasureCameraView(measuredWidth: $vm.measuredWidth, measuredLength: $vm.measuredLength, capturedImage: $vm.capturedImage, isScanning: $vm.isScanning)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .white.opacity(0.45), location: 0.0),
                                            .init(color: Color.luxeFlax.opacity(0.3), location: 0.3),
                                            .init(color: .white.opacity(0.08), location: 0.7),
                                            .init(color: Color.luxeEcru.opacity(0.25), location: 1.0)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    VStack {
                        Text("Place item on flat surface")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.luxeBeige)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .liquidGlassPill(cornerRadius: 10)
                            .padding(.top, 12)
                        Spacer()
                        Image(systemName: "viewfinder")
                            .font(.system(size: 90, weight: .ultraLight))
                            .foregroundColor(.luxeEcru.opacity(0.85))
                        Spacer()
                    }
                }
            }
            .frame(height: 450)
            .padding()
            
            if vm.isScanning {
                VStack(spacing: 8) {
                    ProgressView().tint(Color.luxeFlax)
                    Text("Analyzing with LiDAR & AI...")
                        .font(.caption)
                        .foregroundColor(.luxeFlax)
                }
            } else if vm.capturedImage == nil {
                Button(action: { vm.isScanning = true }) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 76, height: 76)
                            Circle()
                                .fill(Color.luxeGoldGradient)
                                .frame(width: 62, height: 62)
                                .shadow(color: Color.luxeFlax.opacity(0.4), radius: 10)
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.black)
                        }
                        Text("Tap to Scan")
                            .font(.caption.bold())
                            .foregroundColor(.luxeFlax)
                    }
                }
            } else {
                HStack(spacing: 30) {
                    MeasurementBadge(title: "Width", value: vm.measuredWidth)
                    MeasurementBadge(title: "Length", value: vm.measuredLength)
                }
                HStack(spacing: 16) {
                    Button("Retake") { vm.resetScan() }
                        .font(.subheadline.bold())
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .liquidGlassPill(cornerRadius: 12)
                    
                    Button(action: { vm.proceedToReview() }) {
                        Text("Next: AI Review & Sizing")
                            .font(.subheadline.bold())
                            .foregroundColor(.black)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
                            .liquidGlassGoldButton(cornerRadius: 12)
                    }
                }
                .padding(.top, 10)
            }
        }
    }
    
    private var reviewStepView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let img = vm.capturedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .liquidGlassCard(cornerRadius: 16)
                }
                
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        LuxeSectionHeader(title: "ITEM DETAILS")
                        Spacer()
                        Button(action: {
                            vm.autoCategorize()
                        }) {
                            HStack(spacing: 5) {
                                if vm.isAutoCategorizing {
                                    ProgressView()
                                        .tint(.black)
                                        .scaleEffect(0.7)
                                    Text("Categorizing...")
                                } else {
                                    Image(systemName: "sparkles")
                                    Text("Auto-Categorize")
                                }
                            }
                            .font(.caption.bold())
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .liquidGlassGoldButton(cornerRadius: 8)
                        }
                        .disabled(vm.isAutoCategorizing)
                    }
                    
                    if vm.aiCategorizedBadge {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkle")
                                .foregroundColor(.luxeFlax)
                            Text("Auto-categorized by AI")
                                .font(.caption2)
                                .foregroundColor(.luxeFlax)
                        }
                        .padding(.vertical, 2)
                    }
                    
                    HStack {
                        Text("Category").foregroundColor(.gray); Spacer()
                        Picker("", selection: $vm.category) {
                            Text("Top").tag("Top")
                            Text("Bottom").tag("Bottom")
                            Text("Shoes").tag("Shoes")
                            Text("Accessories").tag("Accessories")
                        }
                        .tint(Color.luxeFlax)
                        .onChange(of: vm.category) { _, _ in vm.performAIAnalysis() }
                    }
                    Divider().background(Color.white.opacity(0.1))
                    HStack {
                        Text("Type").foregroundColor(.gray)
                        Spacer()
                        TextField("e.g. Sunglasses, T-Shirt", text: $vm.subCategory)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.luxeBeige)
                    }
                }
                .padding()
                .liquidGlassCard(cornerRadius: 16)
                
                VStack(alignment: .leading, spacing: 15) {
                    LuxeSectionHeader(title: "LIDAR DATA")
                    HStack {
                        Text("Width").foregroundColor(.gray)
                        Spacer()
                        Text(String(format: "%.1f\"", vm.measuredWidth ?? 0))
                            .foregroundColor(.luxeBeige)
                    }
                    Divider().background(Color.white.opacity(0.1))
                    HStack {
                        Text("Length").foregroundColor(.gray)
                        Spacer()
                        Text(String(format: "%.1f\"", vm.measuredLength ?? 0))
                            .foregroundColor(.luxeBeige)
                    }
                }
                .padding()
                .liquidGlassCard(cornerRadius: 16)
                
                VStack(alignment: .leading, spacing: 15) {
                    LuxeSectionHeader(title: "AI SIZING")
                    if vm.isAnalyzingAI {
                        HStack {
                            Text("Calculating...").foregroundColor(.luxeEcru)
                            Spacer()
                            ProgressView().tint(Color.luxeEcru)
                        }
                    } else {
                        HStack {
                            Text("Estimated Size").foregroundColor(.gray)
                            Spacer()
                            Text(vm.size).font(.title3.bold()).foregroundColor(.luxeFlax)
                        }
                        Text("Based on standard US sizing charts using your LiDAR measurements.")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .liquidGlassCard(cornerRadius: 16)
                
                Button(action: { vm.saveSmartItem { presentationMode.wrappedValue.dismiss() } }) {
                    if vm.closetVM.isUploading || vm.isValidating {
                        HStack {
                            Text(vm.isValidating ? "Validating..." : "Saving...")
                            Spacer()
                            ProgressView().tint(.black)
                        }
                        .padding()
                        .liquidGlassGoldButton(cornerRadius: 14)
                    } else {
                        Text("Save to Closet")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .liquidGlassGoldButton(cornerRadius: 14)
                    }
                }
                .disabled(vm.isAnalyzingAI || vm.isAutoCategorizing || vm.closetVM.isUploading || vm.isValidating)
                .padding(.top, 10)
            }
            .padding(20)
        }
    }
}

struct LuxeSectionHeader: View { let title: String; var body: some View { Text(title).font(.caption).fontWeight(.bold).foregroundColor(.luxeFlax).tracking(1) } }

struct MeasurementBadge: View {
    let title: String; let value: Double?
    var body: some View {
        VStack {
            Text(title).font(.caption).foregroundColor(.gray)
            Text(value != nil ? String(format: "%.1f\"", value!) : "--").font(.title2.bold()).foregroundColor(.luxeBeige)
        }
        .frame(width: 100, height: 70)
        .liquidGlassCard(cornerRadius: 12)
    }
}
