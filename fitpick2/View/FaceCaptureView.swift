//
//  FaceCaptureView.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 1/26/26.
//

import SwiftUI
import PhotosUI

struct FaceCaptureView: View {
    @StateObject var camera = SelfieCameraManager()
    @Binding var selectedImage: UIImage?

    @Environment(\.dismiss) var dismiss
    
    @State private var showInstructions = true
    @State private var pickerItem: PhotosPickerItem?
    
    // Logic to disable camera and show loading during gallery processing
    @State private var isProcessingGallery = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    let fitPickGold = Color("fitPickGold")
    let fitPickBlack = Color(red: 26/255, green: 26/255, blue: 27/255)

    let ovalWidth: CGFloat = 350
    let ovalHeight: CGFloat = 500

    var body: some View {
        ZStack {
            fitPickBlack.ignoresSafeArea()

            if let previewImage = camera.capturedImage {
                VStack(spacing: 20) {
                    Text("Review Your Selfie").font(.headline).foregroundColor(fitPickGold)
                    
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: ovalWidth, height: ovalHeight)
                        .clipShape(Ellipse())
                        .overlay(Ellipse().stroke(fitPickGold, lineWidth: 3))

                    HStack(spacing: 40) {
                        Button("Retake") {
                            camera.capturedImage = nil
                            camera.startSession()
                        }.foregroundColor(.white)

                        Button("Use Photo") {
                            selectedImage = previewImage
                            dismiss()
                        }
                        .padding()
                        .background(fitPickGold)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                    }
                }
            } else {
                ZStack {
                    // Disable camera preview layer visually when processing
                    SelfieCameraPreview(session: camera.session)
                        .ignoresSafeArea()
                        .opacity(isProcessingGallery ? 0.5 : 1.0)

                    Color.black.opacity(0.5).mask(
                        ZStack {
                            Rectangle()
                            Ellipse()
                                .frame(width: ovalWidth, height: ovalHeight)
                                .blendMode(.destinationOut)
                        }
                    )

                    Ellipse()
                        .stroke(camera.isFaceInFrame ? Color.green : fitPickGold, lineWidth: 3)
                        .frame(width: ovalWidth, height: ovalHeight)
                    
                    VStack {
                        if !camera.faceStatus.rawValue.isEmpty && !isProcessingGallery {
                            Text(camera.faceStatus.rawValue)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(camera.isFaceInFrame ? .green : .white)
                                .padding(.vertical, 10).padding(.horizontal, 20)
                                .background(Color.black.opacity(0.7)).clipShape(Capsule())
                                .padding(.top, 60)
                        }
                        
                        // Show a spinner while checking the uploaded photo
                        if isProcessingGallery {
                            VStack(spacing: 10) {
                                ProgressView()
                                    .tint(fitPickGold)
                                    .scaleEffect(1.5)
                                Text("Checking Photo...")
                                    .foregroundColor(fitPickGold)
                                    .font(.caption.bold())
                            }
                            .padding(20)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(15)
                            .padding(.top, 40)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 60) {
                            PhotosPicker(selection: $pickerItem, matching: .images) {
                                VStack {
                                    Image(systemName: "face.smiling")
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.white, fitPickGold],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                }
                                .foregroundColor(.white)
                            }
                            .disabled(isProcessingGallery) // Prevent multiple taps

                            Button(action: { camera.takePhoto() }) {
                                ZStack {
                                    Circle()
                                        .fill(camera.isFaceInFrame ? fitPickGold : Color.gray.opacity(0.5))
                                        .frame(width: 70, height: 70)
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                        .frame(width: 80, height: 80)
                                }
                            }
                            .disabled(!camera.isFaceInFrame || isProcessingGallery)

                            VStack {
                                Image(systemName: "photo").font(.system(size: 28)).opacity(0)
                                Text("Space").font(.caption2).opacity(0)
                            }
                        }
                        .padding(.bottom, 40)
                    }

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
                .onAppear { camera.startSession() }
                .onChange(of: pickerItem) { oldItem, newItem in
                    guard let newItem else { return }
                    
                    Task {
                        // Disable camera logic
                        await MainActor.run {
                            isProcessingGallery = true
                            camera.session.stopRunning() // Stop camera sensor
                        }
                        
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            
                            camera.validateGalleryImage(image) { success, message in
                                DispatchQueue.main.async {
                                    isProcessingGallery = false
                                    if success {
                                        camera.capturedImage = image
                                    } else {
                                        self.alertMessage = message
                                        self.showAlert = true
                                        self.pickerItem = nil
                                        camera.startSession() // Restart camera if photo failed
                                    }
                                }
                            }
                        } else {
                            await MainActor.run {
                                isProcessingGallery = false
                                camera.startSession()
                            }
                        }
                    }
                }
                .alert("Invalid Selfie", isPresented: $showAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(alertMessage)
                }
            }

            if showInstructions {
                InstructionOverlay(fitPickGold: fitPickGold) { showInstructions = false }
            }
        }
    }
}
