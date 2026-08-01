// CapturePipeline.swift
// HaispaceRuntime — Core/Capabilities/Camera

import Foundation
import AVFoundation
import UIKit

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
            Task {
                await RuntimeTimelineLogger.shared.logEvent("[2] AVCapturePhotoOutput.capturePhoto()")
            }
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    // Delegate callback
    nonisolated public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let uniqueID = photo.resolvedSettings.uniqueID
        
        Task {
            await RuntimeTimelineLogger.shared.logEvent("[3] didFinishProcessingPhoto()")
            await self.resolveCapture(uniqueID: uniqueID, photo: photo, error: error)
        }
    }
    
    private func resolveCapture(uniqueID: Int64, photo: AVCapturePhoto, error: Error?) async {
        guard let continuation = activeContinuations.removeValue(forKey: uniqueID) else { return }
        
        if let error = error {
            await RuntimeTimelineLogger.shared.logEvent("CAPTURE ERROR: \(error.localizedDescription)")
            continuation.resume(throwing: error)
            return
        }
        
        guard let fileData = photo.fileDataRepresentation() else {
            await RuntimeTimelineLogger.shared.logEvent("CAPTURE ERROR: fileDataRepresentation is nil")
            continuation.resume(throwing: CameraError.captureFailed)
            return
        }
        
        await RuntimeTimelineLogger.shared.logEvent("[4] Data Created (size: \(fileData.count) bytes)")
        
        // M-010 Phase 3: EXIF Diagnostic
        if let image = UIImage(data: fileData) {
            let orientationStr: String
            switch image.imageOrientation {
            case .up: orientationStr = "Up (Normal)"
            case .down: orientationStr = "Down (180 deg)"
            case .left: orientationStr = "Left (90 deg CCW)"
            case .right: orientationStr = "Right (90 deg CW)"
            case .upMirrored: orientationStr = "Up Mirrored"
            case .downMirrored: orientationStr = "Down Mirrored"
            case .leftMirrored: orientationStr = "Left Mirrored"
            case .rightMirrored: orientationStr = "Right Mirrored"
            @unknown default: orientationStr = "Unknown"
            }
            await RuntimeTimelineLogger.shared.logEvent("EXIF DIAGNOSTIC", payload: "Image Orientation: \(orientationStr)")
        }
        
        // Save to temporary local storage
        let fileName = "capture_\(UUID().uuidString).jpg"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try fileData.write(to: fileURL)
            await RuntimeTimelineLogger.shared.logEvent("[5] File Saved (\(fileURL.path))")
            // Return local file reference
            continuation.resume(returning: fileURL.path)
        } catch {
            await RuntimeTimelineLogger.shared.logEvent("CAPTURE ERROR: Failed to write to \(fileURL.path) - \(error.localizedDescription)")
            continuation.resume(throwing: error)
        }
    }
}
