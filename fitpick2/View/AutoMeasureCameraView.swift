//
//  AutoMeasureCameraView.swift
//  fitpick
//
//  Created by FitPick AI on 2/4/26.
//

import SwiftUI
import ARKit
import Vision

struct AutoMeasureCameraView: UIViewRepresentable {
    @Binding var measuredWidth: Double?
    @Binding var measuredLength: Double?
    @Binding var capturedImage: UIImage?
    @Binding var isScanning: Bool
    
    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView()
        sceneView.delegate = context.coordinator
        
        // Add a layer to draw the green detection box
        let overlayLayer = CAShapeLayer()
        overlayLayer.strokeColor = UIColor.green.cgColor
        overlayLayer.lineWidth = 3
        overlayLayer.fillColor = UIColor.clear.cgColor
        overlayLayer.name = "detectionOverlay"
        sceneView.layer.addSublayer(overlayLayer)
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal] // Explicitly look for tables/floors
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        sceneView.session.run(config)
        
        return sceneView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Ensure the overlay layer fits the view
        if let layer = uiView.layer.sublayers?.first(where: { $0.name == "detectionOverlay" }) as? CAShapeLayer {
            layer.frame = uiView.bounds
        }
        
        if isScanning {
            context.coordinator.startScanning(in: uiView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: AutoMeasureCameraView
        var isProcessing = false
        var retryCount = 0
        let maxRetries = 20 // Keep trying for ~1-2 seconds if it fails initially
        
        init(_ parent: AutoMeasureCameraView) {
            self.parent = parent
        }
        
        func startScanning(in sceneView: ARSCNView) {
            guard !isProcessing else { return }
            isProcessing = true
            retryCount = 0
            performDetection(in: sceneView)
        }
        
        private func performDetection(in sceneView: ARSCNView) {
            guard let frame = sceneView.session.currentFrame else {
                self.isProcessing = false
                return
            }
            
            let pixelBuffer = frame.capturedImage
            let orientation = CGImagePropertyOrientation(rawValue: UInt32(UIDevice.current.orientation.rawValue)) ?? .up
            
            // CHANGED: Use 'Objectness' instead of 'Attention' (Better for whole items like shirts)
            let request = VNGenerateObjectnessBasedSaliencyImageRequest()
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                    
                    guard let observation = request.results?.first as? VNSaliencyImageObservation,
                          let salientObject = observation.salientObjects?.first else {
                        
                        // Retry Logic
                        self.handleFailure(sceneView: sceneView)
                        return
                    }
                    
                    // Success! Calculate size.
                    DispatchQueue.main.async {
                        // Draw the visual feedback box
                        self.drawBoundingBox(rect: salientObject.boundingBox, on: sceneView)
                        
                        // Perform the math
                        self.calculateRealWorldSize(
                            frame: frame,
                            sceneView: sceneView,
                            boundingBox: salientObject.boundingBox,
                            snapshot: sceneView.snapshot()
                        )
                    }
                    
                } catch {
                    print("Vision Error: \(error)")
                    self.handleFailure(sceneView: sceneView)
                }
            }
        }
        
        private func handleFailure(sceneView: ARSCNView) {
            DispatchQueue.main.async {
                if self.retryCount < self.maxRetries {
                    self.retryCount += 1
                    // Wait a tiny bit (50ms) and try again
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        self.performDetection(in: sceneView)
                    }
                } else {
                    print("Failed to detect object after retries.")
                    self.parent.isScanning = false
                    self.isProcessing = false
                }
            }
        }
        
        private func drawBoundingBox(rect: CGRect, on view: ARSCNView) {
            // Vision coordinates are normalized (0-1) with origin at bottom-left.
            // UI coordinates have origin at top-left. We must flip Y.
            let width = view.bounds.width
            let height = view.bounds.height
            
            let x = rect.minX * width
            let y = (1 - rect.maxY) * height // Flip Y
            let w = rect.width * width
            let h = rect.height * height
            
            let uiRect = CGRect(x: x, y: y, width: w, height: h)
            
            if let layer = view.layer.sublayers?.first(where: { $0.name == "detectionOverlay" }) as? CAShapeLayer {
                let path = UIBezierPath(rect: uiRect)
                layer.path = path.cgPath
                
                // Flash animation to indicate success
                let anim = CABasicAnimation(keyPath: "opacity")
                anim.fromValue = 0
                anim.toValue = 1
                anim.duration = 0.1
                layer.add(anim, forKey: "flash")
            }
        }
        
        func calculateRealWorldSize(frame: ARFrame, sceneView: ARSCNView, boundingBox: CGRect, snapshot: UIImage) {
            let screenCenter = CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY)
            
            // Allow ".estimatedPlane" which is more forgiving for soft surfaces like beds/couches
            guard let query = sceneView.raycastQuery(from: screenCenter, allowing: .estimatedPlane, alignment: .any),
                  let result = sceneView.session.raycast(query).first else {
                print("Surface not detected yet. Move iPhone slightly.")
                handleFailure(sceneView: sceneView)
                return
            }
            
            // 1. Distance to object
            let cameraPosition = frame.camera.transform.columns.3
            let hitPosition = result.worldTransform.columns.3
            let distance = simd_distance(cameraPosition, hitPosition)
            
            // 2. Camera Intrinsics
            let intrinsics = frame.camera.intrinsics
            let focalLengthX = intrinsics[0, 0]
            let focalLengthY = intrinsics[1, 1]
            
            let imageWidth = Float(CVPixelBufferGetWidth(frame.capturedImage))
            let imageHeight = Float(CVPixelBufferGetHeight(frame.capturedImage))
            
            // 3. Pixel to Meter conversion
            let objectPixelWidth = Float(boundingBox.width) * imageWidth
            let objectPixelHeight = Float(boundingBox.height) * imageHeight
            
            let realWidthMeters = (objectPixelWidth * distance) / focalLengthX
            let realHeightMeters = (objectPixelHeight * distance) / focalLengthY
            
            let widthInches = Double(realWidthMeters * 39.37)
            let heightInches = Double(realHeightMeters * 39.37)
            
            // 4. Update UI
            DispatchQueue.main.async {
                self.parent.measuredWidth = widthInches
                self.parent.measuredLength = heightInches
                self.parent.capturedImage = snapshot
                self.parent.isScanning = false
                self.isProcessing = false
                
                // Clear the box
                if let layer = sceneView.layer.sublayers?.first(where: { $0.name == "detectionOverlay" }) as? CAShapeLayer {
                    layer.path = nil
                }
            }
        }
    }
}
