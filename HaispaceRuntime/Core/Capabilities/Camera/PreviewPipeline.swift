// PreviewPipeline.swift
// HaispaceRuntime — Core/Capabilities/Camera

import Foundation
import AVFoundation
import CoreImage

/// Pipeline to extract frames from AVCaptureSession without exposing AVFoundation to the UI.
public actor PreviewPipeline: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let videoOutput = AVCaptureVideoDataOutput()
    private var frameContinuation: AsyncStream<CGImage>.Continuation?
    private let context = CIContext()
    
    public var frameStream: AsyncStream<CGImage> {
        AsyncStream { continuation in
            self.frameContinuation = continuation
        }
    }
    
    public override init() {
        super.init()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "PreviewPipelineQueue"))
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
    }
    
    public func attach(to session: AVCaptureSession) throws {
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            // Fix orientation if needed (assuming portrait for iPad kiosk)
            if let connection = videoOutput.connection(with: .video), connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        } else {
            throw CameraError.setupFailed
        }
    }
    
    // Delegate callback
    nonisolated public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Convert to CGImage (Thread safe)
        // We use a local CIContext or a shared one. Since we're nonisolated here, creating one per frame is expensive.
        // We will just pass the CIImage to a helper task.
        Task {
            await self.processFrame(ciImage)
        }
    }
    
    private func processFrame(_ ciImage: CIImage) {
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            frameContinuation?.yield(cgImage)
        }
    }
}
