// CameraSessionController.swift
// HaispaceRuntime — Core/Capabilities/Camera

import Foundation
import AVFoundation
import OSLog

/// Wraps AVCaptureSession. Should not be exposed to UI except via CameraCapabilityService.
public actor CameraSessionController {
    public nonisolated let captureSession = AVCaptureSession()
    private let logger = Logger(subsystem: "id.haispaceproject.runtime", category: "CameraSession")
    
    private var isConfigured = false
    
    public init() {}
    
    public func configure(frameRate: Int) throws {
        guard !isConfigured else { return }
        
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        // 1. Configure Input (Front Camera for Kiosk)
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            logger.error("Failed to acquire camera device.")
            throw CameraError.deviceUnavailable
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        } else {
            throw CameraError.setupFailed
        }
        
        // Output configuration will be handled by pipelines
        
        isConfigured = true
        logger.info("Camera session configured successfully.")
    }
    
    public func start() {
        if !captureSession.isRunning {
            Task.detached {
                self.captureSession.startRunning()
            }
        }
    }
    
    public func stop() {
        if captureSession.isRunning {
            Task.detached {
                self.captureSession.stopRunning()
            }
        }
    }
}

public enum CameraError: Error {
    case deviceUnavailable
    case setupFailed
    case captureFailed
}
