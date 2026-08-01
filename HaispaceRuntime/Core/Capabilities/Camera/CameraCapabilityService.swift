// CameraCapabilityService.swift
// HaispaceRuntime — Core/Capabilities/Camera

import Foundation
import Observation

@Observable
public final class CameraCapabilityService: CameraCapabilityProtocol, @unchecked Sendable {
    public static let shared = CameraCapabilityService()
    
    private let controller = CameraSessionController()
    public let previewPipeline = PreviewPipeline()
    private let capturePipeline = CapturePipeline()
    
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
        RuntimeTimelineLogger.shared.logEvent("CAMERA PREPARE", payload: "FPS: \(configuration.frameRate)")
        
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
        await RuntimeTimelineLogger.shared.logEvent("CAMERA CAPTURE REQUESTED", payload: correlationId.rawValue)
        
        let path = try await capturePipeline.capturePhoto()
        metrics = CameraMetrics(totalCaptures: metrics.totalCaptures + 1)
        
        // Simpan path ke CapturedPhotoStore agar View bisa mengaksesnya
        await CapturedPhotoStore.shared.appendCapture(path: path)
        
        await RuntimeTimelineLogger.shared.logEvent("CAMERA CAPTURE SUCCESS", payload: path)
    }
}
