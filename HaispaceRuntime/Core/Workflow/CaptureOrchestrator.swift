// CaptureOrchestrator.swift
// HaispaceRuntime — Core/Workflow
//
// Sub-Orchestrator khusus untuk domain Capture & Photo Input Stream.
// Mengisolasi Camera preparation, Session Timer, Photo Input Stream (P2P/Camera), dan Quota Tracking.
//
// Ref: ADR-016, ADR-017, ADR-018

import Foundation

public actor CaptureOrchestrator {
    
    // MARK: - Dependencies
    public let camera: CameraCapabilityProtocol
    public let p2p: P2PCapabilityProtocol
    
    // MARK: - Properties
    private var activeSessionId: SessionID?
    private var currentCorrelationId: CorrelationID?
    
    private var photoInputListenerTask: Task<Void, Never>?
    private var photoFullQualityListenerTask: Task<Void, Never>?
    
    private let sessionTimer = SessionTimer()
    private var sessionTimerTask: Task<Void, Never>?
    private(set) public var sessionTimerRemaining: Int = 0
    
    // MARK: - Initializer
    public init(
        camera: CameraCapabilityProtocol,
        p2p: P2PCapabilityProtocol
    ) {
        self.camera = camera
        self.p2p = p2p
    }
    
    // MARK: - Capture Lifecycle Methods
    
    /// Menyiapkan kamera dan memulai sesi capture foto.
    public func prepareCaptureSession(sessionId: SessionID, packageId: String) async throws {
        self.activeSessionId = sessionId
        try await camera.prepare(configuration: CameraConfiguration())
        try await camera.startSession(sessionId: sessionId)
        
        startPhotoInputListening()
        startSessionCountdown(duration: 300)
    }
    
    /// Pemicu shutter kamera.
    public func requestShutter(correlationId: CorrelationID) async throws {
        guard activeSessionId != nil else { throw WorkflowError.sessionNotActive }
        self.currentCorrelationId = correlationId
        try await camera.requestCapture(correlationId: correlationId)
    }
    
    /// Hentikan sesi capture dan listener foto.
    public func stopCaptureSession() async {
        stopPhotoInputListening()
        stopSessionCountdown()
        await camera.stopSession()
        self.activeSessionId = nil
        self.currentCorrelationId = nil
    }
    
    // MARK: - Photo Input Stream Lifecycle
    
    public func startPhotoInputListening() {
        stopPhotoInputListening()
        
        photoInputListenerTask = Task { [weak self] in
            guard self != nil else { return }
            for await message in await P2PMessageRouter.shared.messageStream(for: .photoPreview) {
                guard !Task.isCancelled else { break }
                guard case .photoPreview(let id, let thumbnailData) = message else { continue }
                await MainActor.run {
                    CapturedPhotoStore.shared.receivePhotoEvent(
                        .thumbnailArrived(
                            photoId: id,
                            data: thumbnailData,
                            capturedAt: Date(),
                            sortOrder: CapturedPhotoStore.shared.capturedPhotos.count
                        )
                    )
                }
            }
        }
        
        photoFullQualityListenerTask = Task { [weak self] in
            guard self != nil else { return }
            for await message in await P2PMessageRouter.shared.messageStream(for: .photoFull) {
                guard !Task.isCancelled else { break }
                guard case .photoFull(let id, let fullData) = message else { continue }
                await MainActor.run {
                    CapturedPhotoStore.shared.receivePhotoEvent(
                        .fullQualityArrived(photoId: id, fullData: fullData)
                    )
                }
                let checksum = String(fullData.count)
                await P2PMessageRouter.shared.route(.photoAck(photoId: id, checksum: checksum))
            }
        }
        
        HaispaceLogger.info("[CaptureOrchestrator] Photo Input listening started", category: "workflow")
    }
    
    public func stopPhotoInputListening() {
        photoInputListenerTask?.cancel()
        photoInputListenerTask = nil
        photoFullQualityListenerTask?.cancel()
        photoFullQualityListenerTask = nil
        HaispaceLogger.info("[CaptureOrchestrator] Photo Input listening stopped", category: "workflow")
    }
    
    // MARK: - Session Timer Controls
    
    public func startSessionCountdown(duration: Int) {
        stopSessionCountdown()
        sessionTimerRemaining = duration
        
        sessionTimerTask = Task { [weak self] in
            guard let self else { return }
            for await event in sessionTimer.start(duration: duration) {
                guard !Task.isCancelled else { break }
                switch event {
                case .tick(let remaining):
                    await self.updateTimerRemaining(remaining)
                case .finished, .paused, .resumed:
                    break
                }
            }
        }
    }
    
    private func updateTimerRemaining(_ remaining: Int) {
        self.sessionTimerRemaining = remaining
    }
    
    public func stopSessionCountdown() {
        sessionTimer.stop()
        sessionTimerTask?.cancel()
        sessionTimerTask = nil
        sessionTimerRemaining = 0
    }
}
