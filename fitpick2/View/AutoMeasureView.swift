//
//  AutoMeasureView.swift
//  fitpick2
//
//  Created by Amuel Ryco Nidoy on 1/27/26.
//

import SwiftUI
import CoreData
import AVFoundation
import Vision
import FirebaseStorage
import FirebaseFirestore

struct AutoMeasureView: View {
    
    @StateObject private var cameraManager = CameraManager()
    @State private var statusText = "Align person in frame"
    @State private var jointPoints: [CGPoint] = []
    @State private var bodyJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    
    @State private var userHeightCM: Double = 175.0 // Example height
    @State private var measurements: [String: String] = [:]
    
    @State private var isLocked = false
    
    @EnvironmentObject var session: UserSession
    @Environment(\.dismiss) var dismiss // Add this line
    
    @State private var countdown = 5
    @State private var isTimerRunning = false
    @State private var timer: Timer? = nil

    
    // ADD THIS: A closure to return the final values
    var onCapture: ((Double, Double, Double, Double, Double, Double, Double) -> Void)?
    
    var body: some View {
            ZStack {
                // Camera Preview (Custom view to show AVFoundation layer)
                CameraPreview(session: cameraManager.session)
                    .ignoresSafeArea()
                
                GeometryReader { geo in
                    ZStack {
                        // The skeleton lines
                        SkeletonView(joints: bodyJoints, size: geo.size)

                        ForEach(Array(bodyJoints.values), id: \.self) { point in
                                Circle()
                                    .fill(Color.green) // Use green so you can see them clearly!
                                    .frame(width: 8, height: 8)
                                    .position(x: point.x * geo.size.width, y: point.y * geo.size.height)
                            }
                    }
                }.ignoresSafeArea()
                
                if isTimerRunning {
                    Text("\(countdown)")
                        .font(.system(size: 120, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                        .shadow(color: .black.opacity(0.5), radius: 10)
                        .transition(.scale)
                        .zIndex(1) // Ensure it's above the skeleton
                }
                
                VStack {
                    HStack {
                        Button(action: {
                            // This triggers the dismissal of the fullScreenCover
                            // If you are using 'dismiss' environment variable:
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white.opacity(0.8))
                                .padding()
                        }
                        Spacer()
                        
                        Button(action: {
                                cameraManager.switchCamera()
                            }) {
                                Image(systemName: "camera.rotate.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding()
                            }
                        
                    }
                    Spacer()
                }
                
                // HUD Overlay
                VStack {
                    // Height Input
                    HStack {
                        Text("Your Height:").foregroundColor(.white).bold()
                        TextField("cm", value: $userHeightCM, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 70)
                        Text("cm").foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                    
                    Text(statusText)
                        .padding()
                        .background(isLocked ? Color.blue.opacity(0.8) : Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    
                    Spacer()
                    
                    // CAPTURE BUTTON
                    Button(action: {
                        captureAndLog()
                    }) {
                        Text(isLocked ? "RE-SCAN" : "CAPTURE MEASUREMENTS")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(statusText.contains("✅") ? Color.green : Color.gray)
                            .cornerRadius(15)
                    }
                    .disabled(!statusText.contains("✅") && !isLocked)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
                .padding(.top, 50)
                
                
                Spacer() // Pushes the results to the bottom
                
               
                    
                if !measurements.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Body Measurements").font(.headline).padding(.bottom, 2)
                            Divider().background(Color.white)
                            
                            ForEach(measurements.keys.sorted(), id: \.self) { key in
                                HStack {
                                    Text("\(key):").bold()
                                    Spacer()
                                    Text(measurements[key] ?? "")
                                }
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 15).fill(.black.opacity(0.0)))
                        .foregroundColor(.white)
                        .frame(width: 250)
                        .padding(.bottom, 40)
                    }
            }
            .onAppear {
                cameraManager.onFrameDetected = { buffer in
                    self.processFrame(buffer)
                }
            }.onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    
    func startCountdown() {
        isTimerRunning = true
        countdown = 5
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if countdown > 1 {
                countdown -= 1
                // Optional: Light haptic tick every second
                UISelectionFeedbackGenerator().selectionChanged()
            } else {
                stopTimer()
                captureAndLog() // Trigger the capture
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
    }

    func resetCountdown() {
        if isTimerRunning {
            stopTimer()
            countdown = 5
        }
    }

    func processFrame(_ buffer: CMSampleBuffer) {
        
        let orientation: CGImagePropertyOrientation = (cameraManager.cameraPosition == .front) ? .leftMirrored : .right
        
        // 1. Use .right orientation for the back camera in Portrait mode
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cmSampleBuffer: buffer, orientation: .right, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let result = request.results?.first else {
                return
            }
            
            // 2. Get all recognized points
            let joints = try result.recognizedPoints(.all)
            
            var tempJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
            
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return }
            let imageSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
            
            for (key, point) in joints where point.confidence > 0.5 {
                        // 3. THIS IS THE KEY FIX:
                        // This helper converts the 'Vision Point' to an 'Image Point'
                        let imagePoint = VNImagePointForNormalizedPoint(point.location, Int(imageSize.width), Int(imageSize.height))
                        
                        // 4. Map to SwiftUI Space (Top-Left Origin)
                        // We use the aspect ratio of the image to ensure the Y-axis isn't 'squashed'
                        tempJoints[key] = CGPoint(x: imagePoint.x / imageSize.width,
                                                  y: 1 - (imagePoint.y / imageSize.height))
                    }
            
            DispatchQueue.main.async {
                // ONLY update if we haven't locked the measurements yet
                if !self.isLocked {
                    self.bodyJoints = tempJoints
                    
                    if let leftAnkle = try? result.recognizedPoint(.leftAnkle), leftAnkle.confidence > 0.5,
                       let rightAnkle = try? result.recognizedPoint(.rightAnkle), rightAnkle.confidence > 0.5 {
                        self.statusText = "Person Fully Detected! ✅"
                        self.calculateMeasurements()
                        
                        if cameraManager.cameraPosition == .front && !isTimerRunning {
                                    startCountdown()
                                }
                        
                    } else {
                        self.statusText = "Step back: Feet not visible"
                    }
                } else {
                    self.statusText = "Measurements Locked 🔒"
                    resetCountdown()
                }
            }
            
            
        } catch {
            print("Vision error: \(error)")
        }
    }
    
    func calculateMeasurements() {
        guard let nose = bodyJoints[.nose],
              let leftAnkle = bodyJoints[.leftAnkle],
              let rightAnkle = bodyJoints[.rightAnkle],
              let leftShoulder = bodyJoints[.leftShoulder],
              let rightShoulder = bodyJoints[.rightShoulder],
              let leftHip = bodyJoints[.leftHip],
              let rightHip = bodyJoints[.rightHip],
              let leftElbow = bodyJoints[.leftElbow],
              let leftWrist = bodyJoints[.leftWrist] else { return }

        // --- STEP 1: Scaling ---
        let noseToAnklePixels = hypot(nose.x - ((leftAnkle.x + rightAnkle.x)/2),
                                      nose.y - ((leftAnkle.y + rightAnkle.y)/2))
        let totalHeightPixels = noseToAnklePixels / 0.93
        let ratio = userHeightCM / totalHeightPixels

        // --- STEP 2: New Metrics ---
        
        // Shoulder Width: Straight line distance between shoulders
        let shoulderWidthPixels = hypot(leftShoulder.x - rightShoulder.x, leftShoulder.y - rightShoulder.y)
        let shoulderWidthCM = shoulderWidthPixels * ratio

        // Chest: Vision doesn't have a "Chest" point, so we use the midpoint between shoulders
        // and hips or measure the shoulder width and apply a slightly smaller ratio.
        // Standard estimate: 2D width at the shoulder/armpit level * PI
        let chestCircumferenceCM = (shoulderWidthPixels * 0.95 * ratio) * .pi

        // Hips: Distance between left and right hip joints * PI
        let hipWidthPixels = hypot(leftHip.x - rightHip.x, leftHip.y - rightHip.y)
        let hipsCircumferenceCM = (hipWidthPixels * 1.15 * ratio) * .pi // Hips are usually wider than the bone joints

        // --- STEP 3: Existing Metrics ---
        let totalArmCM = (hypot(leftShoulder.x - leftElbow.x, leftShoulder.y - leftElbow.y) +
                          hypot(leftElbow.x - leftWrist.x, leftElbow.y - leftWrist.y)) * ratio
        let inseamCM = hypot(leftHip.x - leftAnkle.x, leftHip.y - leftAnkle.y) * ratio
        let waistCircumferenceCM = (hipWidthPixels * ratio) * .pi

        DispatchQueue.main.async {
            self.measurements = [
                "Height": "\(Int(userHeightCM)) cm",
                "Arm": String(format: "%.1f cm", totalArmCM),
                "Inseam": String(format: "%.1f cm", inseamCM),
                "Waist": String(format: "%.1f cm", waistCircumferenceCM),
                "Shoulder": String(format: "%.1f cm", shoulderWidthCM),
                "Chest": String(format: "%.1f cm", chestCircumferenceCM),
                "Hips": String(format: "%.1f cm", hipsCircumferenceCM)
            ]
        }
    }
    
    func captureAndLog() {
        if isLocked {
            // Reset to allow a new scan
            isLocked = false
            measurements = [:]
        } else {
            // Lock the values and Print
            isLocked = true
            
            guard let buffer = cameraManager.currentBuffer else { return }
            
            uploadCapturedImage(buffer: buffer) { imageUrl in
                guard let url = imageUrl else {
                    print("Failed to get image URL")
                    return
                }
                let dataToSave: [String: Any] = ["bodybase": url]
                let db = Firestore.firestore()
                
                db.collection("users").document(session.email ?? "").setData(dataToSave, merge: true){ error in
                        if let error = error {
                            print("❌ Error updating Firestore: \(error.localizedDescription)")
                        } else {
                            print("✅ Successfully saved image URL and measurements to Firestore")
                        }
                    }
        
            }
            
            let h = userHeightCM
            let w = extractDouble(from: measurements["Waist"])
            let i = extractDouble(from: measurements["Inseam"])
            let a = extractDouble(from: measurements["Arm"])
            let s = extractDouble(from: measurements["Shoulder"])
            let c = extractDouble(from: measurements["Chest"])
            let hi = extractDouble(from: measurements["Hips"])
            
            onCapture?(h, w, i, a, s, c, hi)
                        
            print("--- DATA SENT TO PROFILE ---")
            
            // Haptic feedback to let the user know it's captured
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        }
    }
    
    func extractDouble(from string: String?) -> Double {
        guard let s = string else { return 0 }
        // This cleans "80.5 cm (est)" or "60.0 cm" into "80.5"
        let cleaned = s.replacingOccurrences(of: " cm", with: "")
                       .replacingOccurrences(of: " (est)", with: "")
                       .trimmingCharacters(in: .whitespaces)
        return Double(cleaned) ?? 0
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    var currentBuffer: CMSampleBuffer?
    
    // Track the current camera position
        @Published var cameraPosition: AVCaptureDevice.Position = .back

    
    // This is where the processed Vision results will be sent
    var onFrameDetected: ((CMSampleBuffer) -> Void)?

    override init() {
        super.init()
        setupSession()
    }
    
    func switchCamera() {
            sessionQueue.async {
                self.cameraPosition = (self.cameraPosition == .back) ? .front : .back
                self.setupSession()
            }
        }

    private func setupSession() {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.inputs.forEach { self.session.removeInput($0) }
            
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.cameraPosition),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
            
            if self.session.canAddInput(videoInput) { self.session.addInput(videoInput) }
            
            if self.session.outputs.isEmpty {
                if self.session.canAddOutput(self.videoOutput) {
                    self.session.addOutput(self.videoOutput)
                    self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.queue"))
                }
            }
            self.session.commitConfiguration()
            if !self.session.isRunning { self.session.startRunning() }
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Send the raw frame to our processor
        self.currentBuffer = sampleBuffer // Store it
        onFrameDetected?(sampleBuffer)
    }
}

struct SkeletonView: View {
    var joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    var size: CGSize

    // This map tells the app which dots to connect with lines
    private let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.neck, .leftShoulder), (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.neck, .rightShoulder), (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip), (.leftHip, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle)
    ]

    var body: some View {
        Path { path in
            for connection in connections {
                if let startPoint = joints[connection.0],
                   let endPoint = joints[connection.1] {
                    // Convert normalized 0-1 points to actual screen pixels
                    path.move(to: CGPoint(x: startPoint.x * size.width, y: startPoint.y * size.height))
                    path.addLine(to: CGPoint(x: endPoint.x * size.width, y: endPoint.y * size.height))
                }
            }
        }
        .stroke(Color.green, lineWidth: 3)
    }
}

extension AutoMeasureView {
    
    func uploadCapturedImage(buffer: CMSampleBuffer, completion: @escaping (String?) -> Void) {
        // 1. Convert Buffer to UIImage
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else {
            completion(nil)
            return
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            completion(nil)
            return
        }

        let uiOrientation: UIImage.Orientation = (cameraManager.cameraPosition == .front) ? .leftMirrored : .right
        let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: uiOrientation)
        guard let imageData = uiImage.jpegData(compressionQuality: 0.7) else {
            completion(nil)
            return
        }
        
        // 2. Upload to Cloud Storage
        let storageRef = Storage.storage().reference().child("users/\(session.email ?? "")/body_base2.jpg")
        
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                print("Error uploading: \(error)")
                completion(nil)
                return
            }
            
            storageRef.downloadURL { url, error in
                completion(url?.absoluteString)
            }
        }
    }
}


