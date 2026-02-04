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
    @Binding var isScanning: Bool // Triggers the measurement logic
    
    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView()
        sceneView.delegate = context.coordinator
        
        let config = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        sceneView.session.run(config)
        
        return sceneView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        if isScanning {
            context.coordinator.performAutoMeasurement(in: uiView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: AutoMeasureCameraView
        var isProcessing = false
        
        init(_ parent: AutoMeasureCameraView) {
            self.parent = parent
        }
        
        func performAutoMeasurement(in sceneView: ARSCNView) {
            guard !isProcessing, let frame = sceneView.session.currentFrame else { return }
            isProcessing = true
            
            let pixelBuffer = frame.capturedImage
            let orientation = CGImagePropertyOrientation(rawValue: UInt32(UIDevice.current.orientation.rawValue)) ?? .up
            
            // Use Saliency to find "interesting" objects (the clothes)
            let request = VNGenerateAttentionBasedSaliencyImageRequest()
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                    
                    // FIX IS HERE: Access 'salientObjects' inside the observation
                    guard let observation = request.results?.first as? VNSaliencyImageObservation,
                          let salientObject = observation.salientObjects?.first else {
                        print("Vision: No salient object found.")
                        self.resetState()
                        return
                    }
                    
                    // Use the bounding box of the first salient object found
                    self.calculateRealWorldSize(frame: frame, sceneView: sceneView, boundingBox: salientObject.boundingBox)
                    
                } catch {
                    print("Vision Error: \(error)")
                    self.resetState()
                }
            }
        }
        
        func calculateRealWorldSize(frame: ARFrame, sceneView: ARSCNView, boundingBox: CGRect) {
            let screenCenter = CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY)
            
            guard let query = sceneView.raycastQuery(from: screenCenter, allowing: .estimatedPlane, alignment: .any),
                  let result = sceneView.session.raycast(query).first else {
                print("Surface not detected yet. Move iPhone slightly.")
                resetState()
                return
            }
            
            // Calculate Distance (Depth)
            let cameraPosition = frame.camera.transform.columns.3
            let hitPosition = result.worldTransform.columns.3
            let distance = simd_distance(cameraPosition, hitPosition)
            
            // Convert Pixels to Real World Size
            let intrinsics = frame.camera.intrinsics
            let focalLengthX = intrinsics[0, 0]
            let focalLengthY = intrinsics[1, 1]
            
            let imageWidth = Float(CVPixelBufferGetWidth(frame.capturedImage))
            let imageHeight = Float(CVPixelBufferGetHeight(frame.capturedImage))
            
            let objectPixelWidth = Float(boundingBox.width) * imageWidth
            let objectPixelHeight = Float(boundingBox.height) * imageHeight
            
            let realWidthMeters = (objectPixelWidth * distance) / focalLengthX
            let realHeightMeters = (objectPixelHeight * distance) / focalLengthY
            
            let widthInches = Double(realWidthMeters * 39.37)
            let heightInches = Double(realHeightMeters * 39.37)
            
            let snapshot = sceneView.snapshot()
            
            DispatchQueue.main.async {
                self.parent.measuredWidth = widthInches
                self.parent.measuredLength = heightInches
                self.parent.capturedImage = snapshot
                self.parent.isScanning = false
                self.isProcessing = false
            }
        }
        
        
        
        func resetState() {
            DispatchQueue.main.async {
                self.parent.isScanning = false
                self.isProcessing = false
            }
        }
    }
}
