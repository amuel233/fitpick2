//
//  VirtualFittingView.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 8/14/26.
//

import SwiftUI
import UIKit

struct VirtualFittingView: View {
    @Binding var isShowingPopup: Bool
    @Binding var backgroundPrompt: String
    @Binding var generatedImage: UIImage?
    @Binding var isProcessing: Bool
    
    let fitPickBlack: RadialGradient
    var onGenerate: () -> Void
    
    // The FocusState now lives locally inside the sheet's environment
    @FocusState private var isReimagineTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 25) {
            VStack(spacing: 8) {
                Capsule().fill(Color.luxeEcru.opacity(0.3)).frame(width: 40, height: 4).padding(.top, 10)
                Text("THE VIRTUAL FITTING").font(.system(size: 14, weight: .black)).tracking(3).padding(.top, 10).foregroundColor(Color.luxeEcru)
            }
            
            if let uiImage = generatedImage {
                Image(uiImage: uiImage).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width * 0.85, height: 400).clipped()
                    .overlay(Rectangle().stroke(Color.luxeEcru.opacity(0.2), lineWidth: 0.5))
                    .shadow(color: Color.luxeFlax.opacity(0.1), radius: 20, x: 0, y: 10)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("REIMAGINE THE SCENE").font(.system(size: 10, weight: .bold)).tracking(1).foregroundColor(Color.luxeEcru)
                HStack(spacing: 12) {
                    TextField("E.G. A PARISIAN RUNWAY AT NIGHT", text: $backgroundPrompt)
                        .focused($isReimagineTextFieldFocused)
                        .font(.system(size: 13, design: .serif)).italic()
                        .padding(15)
                        .background(Color.white)
                        .cornerRadius(4)
                        .foregroundColor(isReimagineTextFieldFocused ? .black : Color.luxeBeige)
                    
                    Button(action: onGenerate) {
                        ZStack {
                            if isProcessing { ProgressView().tint(.black) }
                            else { Image(systemName: "sparkles").font(.system(size: 16)) }
                        }.frame(width: 48, height: 48).background(Color.luxeGoldGradient).foregroundColor(.black)
                    }.disabled(isProcessing || backgroundPrompt.isEmpty)
                }
            }.padding(.horizontal, 25)
            
            Spacer()
            
            Button(action: { isShowingPopup = false }) {
                Text("CLOSE LOOK").font(.system(size: 12, weight: .black)).tracking(2).foregroundColor(Color.luxeEcru)
                    .frame(maxWidth: .infinity).padding().overlay(Rectangle().stroke(Color.luxeEcru, lineWidth: 1))
            }.padding(.horizontal, 25).padding(.bottom, 30)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(0)
        .background(fitPickBlack.ignoresSafeArea())
    }
}
