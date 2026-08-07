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
        
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            await RuntimeTimelineLogger.shared.auditLog(step: "Camera Permission", status: "INFO", detail: "Requesting")
            _ = await AVCaptureDevice.requestAccess(for: .video)
            await RuntimeTimelineLogger.shared.auditLog(step: "Camera Permission", status: "SUCCESS", detail: "Granted")
        } else if status == .denied || status == .restricted {
            await RuntimeTimelineLogger.shared.auditLog(step: "Camera Permission", status: "FAILED", detail: "Denied")
            throw CameraError.deviceUnavailable
        } else {
            await RuntimeTimelineLogger.shared.auditLog(step: "Camera Permission", status: "SUCCESS", detail: "Already Granted")
        }
        
        try await controller.configure(frameRate: configuration.frameRate)
        try await previewPipeline.attach(to: controller.captureSession)
        try await capturePipeline.attach(to: controller.captureSession)
        
        health = CameraHealth(status: .ready, fps: Double(configuration.frameRate), isConnected: true)
    }
    
    public func startSession(sessionId: SessionID) async throws {
        await RuntimeTimelineLogger.shared.auditLog(step: "Camera Session Started", status: "SUCCESS")
        await RuntimeTimelineLogger.shared.logEvent("CAMERA SESSION START", payload: sessionId.rawValue)
        await controller.start()
    }
    
    public func stopSession() async {
        await RuntimeTimelineLogger.shared.logEvent("CAMERA SESSION STOP")
        await controller.stop()
    }
    
    public func requestCapture(correlationId: CorrelationID) async throws {
        // [1] Shutter Pressed is logged in ActiveSessionView
        
        await RuntimeTimelineLogger.shared.logEvent("[FORENSIC][CAPTURE] capture requested")
        
        let path = try await capturePipeline.capturePhoto()
        await RuntimeTimelineLogger.shared.logEvent("[FORENSIC][CAPTURE] capture completed")
        await RuntimeTimelineLogger.shared.logEvent("[FORENSIC][CAPTURE] photo path = \(path)")
        
        let exists = FileManager.default.fileExists(atPath: path)
        let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
        await RuntimeTimelineLogger.shared.logEvent("[FORENSIC][CAPTURE] fileExists = \(exists)")
        await RuntimeTimelineLogger.shared.logEvent("[FORENSIC][CAPTURE] fileSize = \(size)")
        
        // Cek decode (hindari cache dengan UI image jika memori terbatas, tapi kita buat aman)
        let decodeSuccess = UIImage(contentsOfFile: path) != nil
        await RuntimeTimelineLogger.shared.logEvent("[FORENSIC][CAPTURE] UIImage decode = \(decodeSuccess)")
        
        metrics = CameraMetrics(totalCaptures: metrics.totalCaptures + 1)
        
        // Simpan path ke CapturedPhotoStore agar View bisa mengaksesnya
        await CapturedPhotoStore.shared.appendCapture(path: path)
        
        let storeCount = await CapturedPhotoStore.shared.capturedPhotos.count
        await RuntimeTimelineLogger.shared.logEvent("[FORENSIC][CAPTURE] CapturedPhotoStore count = \(storeCount)")
    }
}
