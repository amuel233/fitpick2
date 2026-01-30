//
//  SelfieCameraManager.swift
//  fitpick2
//
//  Created by Karry Raia Oberes on 1/27/26.
//

import AVFoundation
import Vision
import UIKit

class SelfieCameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var capturedImage: UIImage? = nil
    @Published var isFaceInFrame = false
    @Published var faceStatus: FaceStatus = .none
    
    enum FaceStatus: String {
        case none = ""
        case tooClose = "Too close! Move back"
        case lowLight = "Too dark! Find better light"
        case moveBack = "Center your face"
        case good = "Perfect! Stay still"
        case noFace = "Align face in frame"
    }
    
    private let photoOutput = AVCapturePhotoOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let videoQueue = DispatchQueue(label: "camera.video.queue")

    override init() {
        super.init()
        setupSession()
    }

    // MARK: - LIVE CAMERA LOGIC
    func setupSession() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        if session.canAddOutput(videoDataOutput) {
            videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
            session.addOutput(videoDataOutput)
        }
        session.commitConfiguration()
    }

    func startSession() {
        if !session.isRunning {
            DispatchQueue.global(qos: .background).async {
                self.session.startRunning()
            }
        }
    }

    func takePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - STATIC GALLERY LOGIC
    func validateGalleryImage(_ image: UIImage, completion: @escaping (Bool, String) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(false, "Invalid image format.")
            return
        }
        
        let request = VNDetectFaceRectanglesRequest { request, error in
            guard let results = request.results as? [VNFaceObservation], let face = results.first else {
                completion(false, "No face detected. Please use a clear selfie.")
                return
            }
            
            // Logic specifically for static uploads
            let faceCenter = CGPoint(x: face.boundingBox.midX, y: face.boundingBox.midY)
            let isCentered = (0.2...0.8).contains(faceCenter.x) && (0.2...0.8).contains(faceCenter.y)
            let faceArea = face.boundingBox.width * face.boundingBox.height
            
            if faceArea > 0.65 {
                completion(false, "Face is too close to the camera.")
            } else if faceArea < 0.05 {
                completion(false, "Face is too far away. Please crop the photo.")
            } else if !isCentered {
                completion(false, "Face is not centered in the image.")
            } else {
                completion(true, "Success")
            }
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try? handler.perform([request])
    }
}

// MARK: - REAL-TIME VIDEO LOGIC
extension SelfieCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNDetectFaceLandmarksRequest { [weak self] request, _ in
            guard let self = self,
                  let results = request.results as? [VNFaceObservation],
                  let face = results.first else {
                DispatchQueue.main.async {
                    self?.isFaceInFrame = false
                    self?.faceStatus = .noFace
                }
                return
            }

            // Real-time parameters for the live oval guide
            let faceCenter = CGPoint(x: face.boundingBox.midX, y: face.boundingBox.midY)
            let isCentered = (0.38...0.62).contains(faceCenter.x) && (0.35...0.65).contains(faceCenter.y)
            let faceArea = face.boundingBox.width * face.boundingBox.height
            let quality = face.faceCaptureQuality ?? 1.0

            DispatchQueue.main.async {
                if quality < 0.2 {
                    self.faceStatus = .lowLight
                    self.isFaceInFrame = false
                } else if faceArea > 0.55 {
                    self.faceStatus = .tooClose
                    self.isFaceInFrame = false
                } else if isCentered {
                    self.faceStatus = .good
                    self.isFaceInFrame = true
                } else {
                    self.faceStatus = .moveBack
                    self.isFaceInFrame = false
                }
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored)
        try? handler.perform([request])
    }
}

extension SelfieCameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        DispatchQueue.main.async {
            self.capturedImage = image
            self.session.stopRunning()
        }
    }
}
