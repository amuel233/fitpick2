//
//  FaceCaptureView.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 1/26/26.
//

import SwiftUI
import AVFoundation
import Vision

struct FaceCaptureView: View {
    @StateObject var camera = SelfieCameraManager()
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    @State private var showInstructions = true
    @State private var isFaceDetected = false
    
    let fitPickGold = Color("fitPickGold")
    let fitPickBlack = Color("fitPickBlack")

    var body: some View {
        ZStack {
            fitPickBlack.ignoresSafeArea()

            if let previewImage = camera.capturedImage {
                // --- REVIEW MODE ---
                VStack(spacing: 20) {
                    Text("Review Your Selfie").font(.headline).foregroundColor(fitPickGold)

                    Image(uiImage: previewImage)
                        .resizable().scaledToFill()
                        .frame(width: 280, height: 380).clipShape(Ellipse())
                        .overlay(Ellipse().stroke(fitPickGold, lineWidth: 3))

                    HStack(spacing: 40) {
                        Button("Retake") {
                            camera.capturedImage = nil
                            camera.startSession()
                        }.foregroundColor(.white)

                        Button("Use Photo") {
                            selectedImage = previewImage
                            dismiss()
                        }.padding().background(fitPickGold).foregroundColor(.black).cornerRadius(10)
                    }
                }
            } else {
                // --- LIVE CAMERA MODE ---
                ZStack {
                    SelfieCameraPreview(session: camera.session).ignoresSafeArea()
                    
                    // Oval Mask: Changes color based on face detection
                    Color.black.opacity(0.5).mask(ZStack {
                        Rectangle()
                        Ellipse().frame(width: 260, height: 360).blendMode(.destinationOut)
                    })

                    // The stroke turns GREEN when a face is detected
                    Ellipse()
                        .stroke(isFaceDetected ? .green : fitPickGold, lineWidth: 3)
                        .frame(width: 260, height: 360)
                    
                    // --- UI OVERLAY LAYER ---
                    // Using a separate VStack for instructions and capture button to keep them centered
                    VStack {
                        if isFaceDetected {
                            Text("Face Detected").foregroundColor(.green).bold().padding(.top, 50)
                        }
                        
                        Spacer()
                        
                        Button(action: { camera.takePhoto() }) {
                            Circle()
                                .strokeBorder(isFaceDetected ? .green : fitPickGold, lineWidth: 4)
                                .frame(width: 75, height: 75)
                                .background(isFaceDetected ? Color.green.opacity(0.2) : Color.clear)
                                .clipShape(Circle())
                        }
                        .padding(.bottom, 40)
                        .disabled(!isFaceDetected)
                    }

                    // --- DISMISS BUTTON LAYER ---
                    // Placing this last in the ZStack with an explicit alignment to avoid breaking the layout
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(fitPickGold)
                                    .padding(25)
                            }
                        }
                        Spacer()
                    }
                }
                .onAppear {
                    camera.startSession()
                    setupFaceDetection()
                }
            }

            // --- INSTRUCTIONS ---
            if showInstructions {
                ZStack {
                    Color.black.opacity(0.95).ignoresSafeArea()
                    VStack(spacing: 30) {
                        Image(systemName: "face.dashed").font(.system(size: 80)).foregroundColor(fitPickGold)
                        Text("Selfie Instructions").font(.title2).bold().foregroundColor(fitPickGold)
                        
                        VStack(alignment: .leading, spacing: 15) {
                            HStack { Image(systemName: "lightbulb.fill"); Text("Ensure good lighting.") }
                            HStack { Image(systemName: "person.fill.viewfinder"); Text("Align face in the oval.") }
                        }.foregroundColor(.white)

                        Button("Got it!") { showInstructions = false }
                            .padding().frame(maxWidth: .infinity).background(fitPickGold).foregroundColor(.black).cornerRadius(12).padding(.horizontal, 60)
                    }
                }
            }
        }
    }

    // Logic to detect if a face is in the frame
    private func setupFaceDetection() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation {
                self.isFaceDetected = camera.isFaceInFrame
            }
        }
    }
}
