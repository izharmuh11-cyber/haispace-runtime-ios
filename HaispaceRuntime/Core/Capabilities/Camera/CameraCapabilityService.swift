// CameraCapabilityService.swift
// HaispaceRuntime — Core/Capabilities/Camera

import Foundation
import Observation
import AVFoundation

@Observable
public final class CameraCapabilityService: CameraCapabilityProtocol, @unchecked Sendable {
    public static let shared = CameraCapabilityService()
    
    private let controller = CameraSessionController()
    public let previewPipeline = PreviewPipeline()
    private let capturePipeline = CapturePipeline()

    /// Exposes the AVCaptureSession for CameraPreviewLayerView (M-010).
    /// View layer must ONLY use this for rendering — no control of the session.
    public var captureSession: AVCaptureSession {
        controller.captureSession
    }
    
    public var activeSensorResolution: CMVideoDimensions? {
        controller.activeSensorResolution()
    }
    
    private var health = CameraHealth(status: .unavailable, fps: 0, isConnected: false)
    private var metrics = CameraMetrics(totalCaptures: 0)
    
    public var healthSnapshot: CameraHealth {
        get async { return health }
    }
    
    public var metricsSnapshot: CameraMetrics {
        get async { return metrics }
    }
    
    private init() {}
    
    public func prepare(configuration: CameraConfiguration) async throws {
        await RuntimeTimelineLogger.shared.logEvent("CAMERA PREPARE", payload: "FPS: \(configuration.frameRate)")
        
        try await controller.configure(frameRate: configuration.frameRate)
        try await previewPipeline.attach(to: controller.captureSession)
        try await capturePipeline.attach(to: controller.captureSession)
        
        health = CameraHealth(status: .ready, fps: Double(configuration.frameRate), isConnected: true)
    }
    
    public func startSession(sessionId: SessionID) async throws {
        await RuntimeTimelineLogger.shared.logEvent("CAMERA SESSION START", payload: sessionId.rawValue)
        await controller.start()
    }
    
    public func stopSession() async {
        await RuntimeTimelineLogger.shared.logEvent("CAMERA SESSION STOP")
        await controller.stop()
    }
    
    public func requestCapture(correlationId: CorrelationID) async throws {
        // [1] Shutter Pressed is logged in ActiveSessionView
        
        let path = try await capturePipeline.capturePhoto()
        metrics = CameraMetrics(totalCaptures: metrics.totalCaptures + 1)
        
        // Simpan path ke CapturedPhotoStore agar View bisa mengaksesnya
        await CapturedPhotoStore.shared.appendCapture(path: path)
        
        await RuntimeTimelineLogger.shared.logEvent("[6] CapturedPhotoStore Updated", payload: path)
    }
}
