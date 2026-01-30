//
//  InstructionOverlay.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 1/30/26.
//

import SwiftUI

struct InstructionOverlay: View {
    let fitPickGold: Color
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()
            VStack(spacing: 30) {
                Image(systemName: "face.dashed")
                    .font(.system(size: 80))
                    .foregroundColor(fitPickGold)
                
                Text("Selfie Instructions")
                    .font(.title2).bold()
                    .foregroundColor(fitPickGold)
                
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                        Text("Ensure you are in a well-lit area.")
                    }
                    HStack {
                        Image(systemName: "person.fill.viewfinder")
                        Text("Align your face within the frame.")
                    }
                    HStack {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                        Text("Keep your phone at eye level.")
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 40)

                Button("Got it!") {
                    onDismiss()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(fitPickGold)
                .foregroundColor(.black)
                .cornerRadius(12)
                .padding(.horizontal, 60)
            }
        }
    }
}
