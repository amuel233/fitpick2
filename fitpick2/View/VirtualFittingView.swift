//
//  VirtualFittingView.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 8/14/26.
//

import SwiftUI
import UIKit

struct VirtualFittingView: View {
    var title: String = "THE VIRTUAL FITTING"
    @Binding var isShowingPopup: Bool
    @Binding var backgroundPrompt: String
    @Binding var generatedImage: UIImage?
    @Binding var isProcessing: Bool
    
    var fitPickBlack: RadialGradient = Color.luxeSpotlightGradient
    var onGenerate: () -> Void
    
    // The FocusState now lives locally inside the sheet's environment
    @FocusState private var isReimagineTextFieldFocused: Bool
    
    init(
        title: String = "THE VIRTUAL FITTING",
        isShowingPopup: Binding<Bool>,
        backgroundPrompt: Binding<String>,
        generatedImage: Binding<UIImage?>,
        isProcessing: Binding<Bool>,
        fitPickBlack: RadialGradient = Color.luxeSpotlightGradient,
        onGenerate: @escaping () -> Void
    ) {
        self.title = title
        self._isShowingPopup = isShowingPopup
        self._backgroundPrompt = backgroundPrompt
        self._generatedImage = generatedImage
        self._isProcessing = isProcessing
        self.fitPickBlack = fitPickBlack
        self.onGenerate = onGenerate
    }
    
    var body: some View {
        VStack(spacing: 25) {
            VStack(spacing: 8) {
                Capsule()
                    .fill(Color.luxeEcru.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .padding(.top, 10)
                Text(title)
                    .font(.system(size: 14, weight: .black))
                    .tracking(3)
                    .padding(.top, 10)
                    .foregroundColor(Color.luxeEcru)
            }
            
            if let uiImage = generatedImage {
                ZStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: UIScreen.main.bounds.width * 0.85, height: 400)
                        .clipped()
                        .liquidGlassCard(cornerRadius: 16)
                        .shadow(color: Color.luxeFlax.opacity(0.1), radius: 20, x: 0, y: 10)
                    
                    if isProcessing {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.45))
                            .frame(width: UIScreen.main.bounds.width * 0.85, height: 400)
                        VStack(spacing: 12) {
                            ProgressView().tint(Color.luxeFlax).scaleEffect(1.3)
                            Text("REIMAGINING SCENE...")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(2)
                                .foregroundColor(Color.luxeFlax)
                        }
                    }
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.3))
                    ProgressView().tint(Color.luxeEcru)
                }
                .frame(width: UIScreen.main.bounds.width * 0.85, height: 400)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("REIMAGINE THE SCENE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(Color.luxeEcru)
                
                HStack(spacing: 12) {
                    TextField("E.G. A PARISIAN RUNWAY AT NIGHT", text: $backgroundPrompt)
                        .focused($isReimagineTextFieldFocused)
                        .font(.system(size: 13, design: .serif))
                        .italic()
                        .padding(15)
                        .foregroundColor(isReimagineTextFieldFocused ? .black : Color.luxeBeige)
                        .background(
                            Group {
                                if isReimagineTextFieldFocused {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.white)
                                } else {
                                    Color.clear.liquidGlassPill(cornerRadius: 10)
                                }
                            }
                        )
                    
                    Button(action: onGenerate) {
                        ZStack {
                            if isProcessing {
                                ProgressView().tint(.black)
                            } else {
                                Image(systemName: "sparkles").font(.system(size: 16))
                            }
                        }
                        .frame(width: 48, height: 48)
                        .foregroundColor(.black)
                    }
                    .liquidGlassGoldButton(cornerRadius: 14)
                    .disabled(isProcessing || backgroundPrompt.isEmpty)
                    .opacity(isProcessing || backgroundPrompt.isEmpty ? 0.5 : 1)
                }
            }
            .padding(.horizontal, 25)
            
            Spacer()
            
            LiquidGlassActionButton(
                title: "CLOSE LOOK",
                textColor: Color.luxeEcru,
                isProminent: false,
                width: UIScreen.main.bounds.width * 0.85,
                height: 44
            ) {
                isShowingPopup = false
            }
            .padding(.horizontal, 25)
            .padding(.bottom, 30)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(0)
        .background(LiquidGlassBackgroundView())
    }
}
