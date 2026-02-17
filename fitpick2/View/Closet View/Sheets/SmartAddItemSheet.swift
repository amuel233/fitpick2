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
                Color.luxeSpotlightGradient.ignoresSafeArea()
                VStack(spacing: 20) { if vm.step == 1 { scanStepView } else { reviewStepView } }
            }
            .navigationTitle(vm.step == 1 ? "Scan Item" : "Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }.foregroundColor(.luxeEcru)
                }
            }
            .alert("Invalid Scan", isPresented: $vm.showingErrorAlert) { Button("OK", role: .cancel) { } } message: { Text(vm.errorMessage) }
        }
    }
    
    private var scanStepView: some View {
        VStack {
            ZStack(alignment: .bottom) {
                if let img = vm.capturedImage {
                    Image(uiImage: img).resizable().scaledToFit().cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.luxeEcru, lineWidth: 1))
                        .shadow(color: Color.luxeEcru.opacity(0.3), radius: 10)
                } else {
                    AutoMeasureCameraView(measuredWidth: $vm.measuredWidth, measuredLength: $vm.measuredLength, capturedImage: $vm.capturedImage, isScanning: $vm.isScanning)
                        .cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    VStack {
                        Text("Place item on flat surface").font(.caption).foregroundColor(.luxeBeige).padding(8).background(.ultraThinMaterial).cornerRadius(8).padding(.top, 10)
                        Spacer(); Image(systemName: "viewfinder").font(.system(size: 100, weight: .thin)).foregroundColor(.luxeEcru.opacity(0.8)); Spacer()
                    }
                }
            }.frame(height: 450).padding()
            
            if vm.isScanning {
                VStack { ProgressView().tint(Color.luxeEcru); Text("Analyzing...").font(.caption).foregroundColor(.luxeEcru) }
            } else if vm.capturedImage == nil {
                Button(action: { vm.isScanning = true }) {
                    VStack {
                        Image(systemName: "circle.inset.filled").font(.system(size: 70)).foregroundStyle(Color.luxeGoldGradient).shadow(color: Color.luxeEcru.opacity(0.4), radius: 10)
                        Text("Tap to Scan").font(.caption).foregroundColor(.gray)
                    }
                }
            } else {
                HStack(spacing: 40) { MeasurementBadge(title: "Width", value: vm.measuredWidth); MeasurementBadge(title: "Length", value: vm.measuredLength) }
                HStack(spacing: 20) {
                    Button("Retake") { vm.resetScan() }.foregroundColor(.red.opacity(0.8)).padding()
                    Button(action: { vm.step = 2; vm.performAIAnalysis() }) {
                        Text("Next: AI Sizing").fontWeight(.bold).padding().padding(.horizontal, 20).background(Color.luxeGoldGradient).foregroundColor(.black).cornerRadius(12).shadow(color: Color.luxeEcru.opacity(0.3), radius: 8)
                    }
                }.padding(.top, 10)
            }
        }
    }
    
    private var reviewStepView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let img = vm.capturedImage {
                    Image(uiImage: img).resizable().scaledToFit().frame(height: 180).cornerRadius(12).shadow(radius: 5).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.luxeEcru, lineWidth: 1))
                }
                
                VStack(alignment: .leading, spacing: 15) {
                    LuxeSectionHeader(title: "ITEM DETAILS")
                    HStack {
                        Text("Category").foregroundColor(.gray); Spacer()
                        Picker("", selection: $vm.category) { Text("Top").tag("Top"); Text("Bottom").tag("Bottom"); Text("Shoes").tag("Shoes"); Text("Accessories").tag("Accessories") }.tint(Color.luxeFlax)
                            .onChange(of: vm.category) { _, _ in vm.performAIAnalysis() }
                    }
                    Divider().background(Color.white.opacity(0.1))
                    HStack { Text("Type").foregroundColor(.gray); Spacer(); TextField("e.g. T-Shirt", text: $vm.subCategory).multilineTextAlignment(.trailing).foregroundColor(.luxeBeige) }
                }.padding().background(.ultraThinMaterial).cornerRadius(16)
                
                VStack(alignment: .leading, spacing: 15) {
                    LuxeSectionHeader(title: "LIDAR DATA")
                    HStack { Text("Width").foregroundColor(.gray); Spacer(); Text(String(format: "%.1f\"", vm.measuredWidth ?? 0)).foregroundColor(.luxeBeige) }
                    Divider().background(Color.white.opacity(0.1))
                    HStack { Text("Length").foregroundColor(.gray); Spacer(); Text(String(format: "%.1f\"", vm.measuredLength ?? 0)).foregroundColor(.luxeBeige) }
                }.padding().background(.ultraThinMaterial).cornerRadius(16)
                
                VStack(alignment: .leading, spacing: 15) {
                    LuxeSectionHeader(title: "AI SIZING")
                    if vm.isAnalyzingAI { HStack { Text("Calculating...").foregroundColor(.luxeEcru); Spacer(); ProgressView().tint(Color.luxeEcru) } }
                    else { HStack { Text("Estimated Size").foregroundColor(.gray); Spacer(); Text(vm.size).font(.title3.bold()).foregroundColor(.luxeFlax) }
                        Text("Based on standard US sizing charts using your LiDAR measurements.").font(.caption2).foregroundColor(.gray)
                    }
                }.padding().background(.ultraThinMaterial).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.luxeEcru.opacity(0.3), lineWidth: 1))
                
                Button(action: { vm.saveSmartItem { presentationMode.wrappedValue.dismiss() } }) {
                    if vm.closetVM.isUploading || vm.isValidating {
                        HStack { Text(vm.isValidating ? "Validating..." : "Saving..."); Spacer(); ProgressView().tint(.black) }.padding().background(Color.luxeFlax).foregroundColor(.black).cornerRadius(12)
                    } else {
                        Text("Save to Closet").fontWeight(.bold).frame(maxWidth: .infinity).padding().background(Color.luxeGoldGradient).foregroundColor(.black).cornerRadius(12).shadow(color: Color.luxeEcru.opacity(0.3), radius: 8)
                    }
                }.disabled(vm.isAnalyzingAI || vm.closetVM.isUploading || vm.isValidating).padding(.top, 10)
            }.padding(20).environment(\.colorScheme, .dark)
        }
    }
}

struct LuxeSectionHeader: View { let title: String; var body: some View { Text(title).font(.caption).fontWeight(.bold).foregroundColor(.luxeEcru).tracking(1) } }

struct MeasurementBadge: View {
    let title: String; let value: Double?
    var body: some View {
        VStack { Text(title).font(.caption).foregroundColor(.gray); Text(value != nil ? String(format: "%.1f\"", value!) : "--").font(.title2.bold()).foregroundColor(.luxeBeige) }
            .frame(width: 100, height: 70).background(.ultraThinMaterial).environment(\.colorScheme, .dark).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
