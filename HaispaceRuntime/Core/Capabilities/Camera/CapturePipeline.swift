// CapturePipeline.swift
// HaispaceRuntime — Core/Capabilities/Camera

import Foundation
import AVFoundation

/// Handles high-resolution photo capture without exposing AVFoundation to the orchestrator.
public actor CapturePipeline: NSObject, AVCapturePhotoCaptureDelegate {
    private let photoOutput = AVCapturePhotoOutput()
    private var activeContinuations: [Int64: CheckedContinuation<String, Error>] = [:]
    
    public override init() {
        super.init()
    }
    
    public func attach(to session: AVCaptureSession) throws {
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        } else {
            throw CameraError.setupFailed
        }
    }
    
    public func capturePhoto() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let settings = AVCapturePhotoSettings()
            let uniqueID = settings.uniqueID
            
            // Store continuation
            activeContinuations[uniqueID] = continuation
            
            // Fire capture
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    // Delegate callback
    nonisolated public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let uniqueID = photo.resolvedSettings.uniqueID
        
        Task {
            await self.resolveCapture(uniqueID: uniqueID, photo: photo, error: error)
        }
    }
    
    private func resolveCapture(uniqueID: Int64, photo: AVCapturePhoto, error: Error?) {
        guard let continuation = activeContinuations.removeValue(forKey: uniqueID) else { return }
        
        if let error = error {
            continuation.resume(throwing: error)
            return
        }
        
        guard let fileData = photo.fileDataRepresentation() else {
            continuation.resume(throwing: CameraError.captureFailed)
            return
        }
        
        // Save to temporary local storage
        let fileName = "capture_\(UUID().uuidString).jpg"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try fileData.write(to: fileURL)
            // Return local file reference
            continuation.resume(returning: fileURL.path)
        } catch {
            continuation.resume(throwing: error)
        }
    }
}
