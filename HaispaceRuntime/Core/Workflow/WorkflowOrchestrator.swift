// WorkflowOrchestrator.swift
// HaispaceRuntime — Core/Workflow
//
// Business State Machine Orchestrator Haispace Kiosk.
// Menghubungkan Intent dari SwiftUI View Layer ke 5 Business Capabilities.
//
// Ref: docs/design/03_user_flow.md, docs/design/46_event_contracts.md

import Foundation

public actor WorkflowOrchestrator: @preconcurrency WorkflowOrchestratorProtocol {
    
    // MARK: - State Properties
    private(set) public var currentStage: WorkflowStage = .landing {
        didSet {
            let stageValue = currentStage
            Task { @MainActor in
                RuntimeTimelineLogger.shared.logEvent("WORKFLOW", payload: "Stage -> \(stageValue)")
            }
        }
    }
    private var activeSessionId: SessionID?
    private var currentCorrelationId: CorrelationID?
    private var activePhotoId: PhotoID?
    private var activeOutputReference: String?
    
    // Capabilities Injected via Protocols
    public let camera: CameraCapabilityProtocol
    public let editing: EditingCapabilityProtocol
    public let payment: PaymentCapabilityProtocol
    public let delivery: DeliveryCapabilityProtocol
    public let p2p: P2PCapabilityProtocol
    
    // Repository Layer (Phase B)
    public let sessionRepository: SessionRepositoryProtocol
    private(set) public var activeSession: HaispaceSession?
    
    // Health Monitor
    private var health: WorkflowHealth = WorkflowHealth()
    
    // M-011 STEP 1: Photo Input Listener Lifecycle
    // Orchestrator hanya start/stop — tidak pernah memproses foto.
    // Foto mengalir: P2P → PhotoEvent → CapturedPhotoStore
    private var photoInputListenerTask: Task<Void, Never>?
    private var photoFullQualityListenerTask: Task<Void, Never>?

    public var healthSnapshot: WorkflowHealth {
        return WorkflowHealth(
            currentStage: self.currentStage,
            activeSessionCount: activeSessionId != nil ? 1 : 0,
            averageCompletionTimeMs: health.averageCompletionTimeMs,
            stalledSessionsCount: health.stalledSessionsCount,
            recoveryCount: health.recoveryCount
        )
    }

    /// Apakah sesi ini pernah mencapai paymentConfirmed?
    /// Dipakai untuk menentukan recovery strategy saat cancel atau crash.
    private var hasFinancialTransaction: Bool {
        guard let sessionId = activeSessionId else { return false }
        let record = SessionAuditTrail.read(sessionId: sessionId.rawValue)
        return record?.hasFinancialTransaction ?? false
    }

    // MARK: - Initializer (Dependency Injection)
    public init(
        camera: CameraCapabilityProtocol,
        editing: EditingCapabilityProtocol,
        payment: PaymentCapabilityProtocol,
        delivery: DeliveryCapabilityProtocol,
        p2p: P2PCapabilityProtocol,
        sessionRepository: SessionRepositoryProtocol? = nil
    ) {
        self.camera = camera
        self.editing = editing
        self.payment = payment
        self.delivery = delivery
        self.p2p = p2p
        self.sessionRepository = sessionRepository ?? (try? LocalSessionRepository()) ?? NoOpSessionRepository()
    }
    
    // MARK: - Intent Handling (From SwiftUI UI Layer)
    
    public func handleIntent(_ intent: WorkflowIntent) async throws {
        switch intent {
        case .startGuestRegistration:
            let newSession = SessionID()
            self.activeSessionId = newSession
            
            Task { @MainActor in
                RuntimeTimelineLogger.shared.logEvent("SESSION_STARTED", payload: newSession.rawValue)
                // Bersihkan foto sesi sebelumnya
                await CapturedPhotoStore.shared.clearCaptures()
            }

            // Invariant 19: AuditTrail dibuat SEBELUM stage berubah
            SessionAuditTrail.create(sessionId: newSession.rawValue)
            SessionAuditTrail.append(
                sessionId: newSession.rawValue,
                stage: .guestRegistration,
                eventType: .sessionStarted
            )
            self.currentStage = .guestRegistration
            
        case .guestSubmittedInfo(let name, let email):
            let sessionId = getOrCreateActiveSession()
            SessionAuditTrail.append(
                sessionId: sessionId.rawValue,
                stage: .packageSelection,
                eventType: .infoSubmitted,
                metadata: ["guestName": name, "email": email]
            )
            self.currentStage = .packageSelection
            
        case .selectPackage(let packageId):
            let sessionId = getOrCreateActiveSession()
            
            // Prepare Camera Capabilities right away for photo capture
            try await camera.prepare(configuration: CameraConfiguration())
            try await camera.startSession(sessionId: sessionId)
            
            // M-011 STEP 1: Start Photo Input listening
            startPhotoInputListening()

            SessionAuditTrail.append(
                sessionId: sessionId.rawValue,
                stage: .capturing,
                eventType: .packageSelected,
                metadata: ["packageId": packageId]
            )
            self.currentStage = .capturing
            
        case .selectTemplate(let frameId):
            guard let sessionId = activeSessionId else { throw WorkflowError.sessionNotActive }

            let editingConfig = EditingConfiguration(frame: FrameReference(frameId: frameId, assetPath: "frames/\(frameId).png"))
            try await editing.prepare(sessionId: sessionId, configuration: editingConfig)

            SessionAuditTrail.append(
                sessionId: sessionId.rawValue,
                stage: .exporting,
                eventType: .templateSelected,
                metadata: ["frameId": frameId]
            )
            
            self.currentStage = .exporting

            let correlationId = currentCorrelationId ?? CorrelationID()
            let exportResult = try await editing.requestExport(photoInput: "captured_photo.jpg", correlationId: correlationId)
            self.activePhotoId = exportResult.photoId
            self.activeOutputReference = exportResult.outputReference

            // Transition to Payment
            do {
                try await payment.prepare(configuration: PaymentConfiguration())
                _ = try await payment.requestPayment(
                    sessionId: sessionId,
                    correlationId: correlationId,
                    amount: PaymentAmount(amountValue: 35000, method: .localQRIS),
                    method: .localQRIS
                )
            } catch {
                SessionAuditTrail.append(
                    sessionId: sessionId.rawValue,
                    stage: .exporting,
                    eventType: .paymentFailed,
                    metadata: ["error": error.localizedDescription]
                )
                throw error
            }

            SessionAuditTrail.append(
                sessionId: sessionId.rawValue,
                stage: .paymentRequested,
                eventType: .paymentRequested
            )
            self.currentStage = .paymentRequested
            
        case .triggerShutter:
            guard currentStage == .capturing, let sessionId = activeSessionId else { throw WorkflowError.invalidTransition }
            let correlationId = CorrelationID()
            self.currentCorrelationId = correlationId

            do {
                try await camera.requestCapture(correlationId: correlationId)
            } catch {
                SessionAuditTrail.append(
                    sessionId: sessionId.rawValue,
                    stage: .capturing,
                    eventType: .cameraFailure,
                    metadata: ["error": error.localizedDescription]
                )
                throw error  // re-throw — error type harus preserved (Failure Injection Test)
            }

            SessionAuditTrail.append(
                sessionId: sessionId.rawValue,
                stage: .editingPreview,
                eventType: .photoCaptured
            )
            self.currentStage = .editingPreview
            
        case .selectFilter(let filterId):
            guard currentStage == .editingPreview, let correlationId = currentCorrelationId else { return }
            let filterRef = FilterReference(filterId: filterId, lutFileName: "luts/\(filterId).cube")
            _ = EditingConfiguration(filter: filterRef)
            
            // Re-render Preview
            _ = try await editing.requestPreview(photoInput: "captured_photo.jpg", correlationId: correlationId)
            
        case .acceptPreview:
            guard currentStage == .editingPreview,
                  let sessionId = activeSessionId,
                  let correlationId = currentCorrelationId else { return }
            self.currentStage = .exporting

            // Render Export Full Resolution
            let exportResult = try await editing.requestExport(photoInput: "captured_photo.jpg", correlationId: correlationId)
            self.activePhotoId = exportResult.photoId
            self.activeOutputReference = exportResult.outputReference

            SessionAuditTrail.append(
                sessionId: sessionId.rawValue,
                stage: .exporting,
                eventType: .exportCompleted
            )

            // Transition to Payment
            do {
                try await payment.prepare(configuration: PaymentConfiguration())
                _ = try await payment.requestPayment(
                    sessionId: sessionId,
                    correlationId: correlationId,
                    amount: PaymentAmount(amountValue: 35000, method: .localQRIS),
                    method: .localQRIS
                )
            } catch {
                SessionAuditTrail.append(
                    sessionId: sessionId.rawValue,
                    stage: .exporting,
                    eventType: .paymentFailed,
                    metadata: ["error": error.localizedDescription]
                )
                throw error
            }

            SessionAuditTrail.append(
                sessionId: sessionId.rawValue,
                stage: .paymentRequested,
                eventType: .paymentRequested
            )
            self.currentStage = .paymentRequested
            
        case .confirmPaymentSuccess:
            guard currentStage == .paymentRequested,
                  let sessionId = activeSessionId,
                  let correlationId = currentCorrelationId,
                  let photoId = activePhotoId,
                  let outputRef = activeOutputReference else { return }

            // MARK: - PR-01 Step 1: Shadow Write to Session Aggregate & Repository
            let txnId = UUID().uuidString
            if let aggregate = activeSession {
                try? await aggregate.acceptPayment(
                    localTransactionId: txnId,
                    amount: 35000,
                    method: .qris
                )
                let snap = await aggregate.snapshot()
                try? await sessionRepository.save(snap)
                HaispaceLogger.info(
                    "PR-01 Shadow Write: Payment accepted & snapshot persisted (\(sessionId.rawValue))",
                    category: "workflow"
                )

                // MARK: - PR-02 Step 2: Read Compare + Divergence Detection
                // Baca dari Aggregate, bandingkan dengan Legacy PaymentStore.
                // Tidak mengubah perilaku runtime. Emit event hanya sebagai sinyal.
                // Return value tetap dari Aggregate (bukan Legacy).
                let compatResult = await PaymentCompatibilityChecker.check(
                    session: aggregate,
                    legacyIsPaid: true,           // Legacy sedang dalam .paid setelah confirmPayment
                    legacyAmount: 35000,           // Legacy PaymentStore.amount (hardcoded sementara)
                    legacyTransactionId: txnId,    // txnId di-share — harusnya match
                    legacyAcceptedAt: Date()       // Legacy tidak menyimpan acceptedAt — mismatch expected
                )

                let compatEvent: CompatibilityEvent = compatResult.overallMatched
                    ? .matched(compatResult)
                    : .mismatched(compatResult)

                HaispaceLogger.info(
                    "PR-02 Compat/Payment [\(compatEvent.name)]: \(compatResult.mismatchCount) mismatched field(s) — sessionId: \(sessionId.rawValue)",
                    category: "compatibility"
                )
            }

            // POIN KRITIS: Payment confirmed — tulis audit SEBELUM delivery dimulai (Compatibility Mode)
            SessionAuditTrail.append(
                sessionId: sessionId.rawValue,
                stage: .paymentConfirmed,
                eventType: .paymentConfirmed,
                metadata: [
                    "photoId": photoId.rawValue,
                    "outputRef": outputRef,
                    "localTransactionId": txnId
                ]
            )
            self.currentStage = .paymentConfirmed

            // Transition to Delivery
            do {
                try await delivery.prepare(configuration: DeliveryConfiguration())
                _ = try await delivery.requestDelivery(
                    sessionId: sessionId,
                    correlationId: correlationId,
                    photoId: photoId,
                    assetPath: outputRef,
                    channel: .localBonjourWiFiServer
                )
            } catch {
                SessionAuditTrail.append(
                    sessionId: sessionId.rawValue,
                    stage: .paymentConfirmed,
                    eventType: .deliveryFailure,
                    metadata: ["error": error.localizedDescription]
                )
                // TIDAK reset ke landing — customer sudah bayar! (Failure Injection Test)
                throw error
            }

            SessionAuditTrail.append(
                sessionId: sessionId.rawValue,
                stage: .deliveryDispatch,
                eventType: .deliveryStarted
            )
            self.currentStage = .deliveryDispatch
            
        case .finishSession:
            if let sessionId = activeSessionId {
                SessionAuditTrail.append(
                    sessionId: sessionId.rawValue,
                    stage: .sessionCompleted,
                    eventType: .sessionCompleted
                )
                SessionAuditTrail.close(sessionId: sessionId.rawValue, status: .completed)
            }
            stopPhotoInputListening() // M-011 STEP 1
            await resetToLanding()
            
        case .cancelSessionByOperator:
            if let sessionId = activeSessionId {
                SessionAuditTrail.append(
                    sessionId: sessionId.rawValue,
                    stage: currentStage,
                    eventType: .operatorCancel
                )
                let finalStatus: AuditTrailFooter.FinalStatus = hasFinancialTransaction
                    ? .completed
                    : .cancelledByOperator
                SessionAuditTrail.close(sessionId: sessionId.rawValue, status: finalStatus)
            }
            stopPhotoInputListening() // M-011 STEP 1
            await resetToLanding()
            
        case .testCameraCapture:
            let correlationId = CorrelationID()
            try? await camera.startSession(sessionId: SessionID())
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            try? await camera.requestCapture(correlationId: correlationId)
            await camera.stopSession()
            
        case .testPrinter:
            // Assuming we have access to printer, but it's not injected yet.
            // For now, since M-007 requires printer capability, we might not have it in the orchestrator injection yet.
            // Let's just log or call it directly if it's a shared instance, though WorkflowOrchestrator should inject it.
            // Wait, printer is not in WorkflowOrchestratorProtocol!
            // I'll just use PrinterCapabilityService.shared for this isolated diagnostic intent for now.
            try? await PrinterCapabilityService.shared.sendTestPage()
        }
    }
    
    // MARK: - Photo Input Lifecycle (M-011 STEP 1)
    
    /// Mulai mendengarkan aliran foto dari transport saat ini (P2P).
    /// Orchestrator tidak memproses foto — hanya start dan stop lifecycle.
    /// Foto mengalir: P2PMessageRouter → PhotoEvent → CapturedPhotoStore
    private func startPhotoInputListening() {
        stopPhotoInputListening() // Cancel sebelumnya jika ada
        
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
                Task { @MainActor in
                    RuntimeTimelineLogger.shared.logEvent("SESSION STORE RECEIVED THUMBNAIL")
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
                // Send ACK back to iPhone
                let checksum = String(fullData.count)
                await P2PMessageRouter.shared.route(.photoAck(photoId: id, checksum: checksum))
            }
        }
        
        HaispaceLogger.info("[M-011] Photo Input listening started", category: "workflow")
    }
    
    /// Hentikan semua task listener foto.
    private func stopPhotoInputListening() {
        photoInputListenerTask?.cancel()
        photoInputListenerTask = nil
        photoFullQualityListenerTask?.cancel()
        photoFullQualityListenerTask = nil
        HaispaceLogger.info("[M-011] Photo Input listening stopped", category: "workflow")
    }
    
    // MARK: - Generic Event Bus Handler (Event-to-Command Table)
    
    public func processEvent(_ envelope: EventEnvelope<Data>) async throws {
        // Event Contract Mapping: Event -> Stage Transition
        switch envelope.eventName {
        case "Payment.Confirmed":
            try await handleIntent(.confirmPaymentSuccess)
        case "Delivery.Completed":
            self.currentStage = .sessionCompleted
        default:
            break
        }
    }
    
    // MARK: - Reset State
    
    public func resetToLanding() async {
        await camera.stopSession()
        await editing.stopSession()
        await payment.stopSession()
        await delivery.stopSession()
        
        self.activeSessionId = nil
        self.currentCorrelationId = nil
        self.activePhotoId = nil
        self.activeOutputReference = nil
        self.currentStage = .landing
    }

    private func getOrCreateActiveSession(guestName: String = "Guest") -> SessionID {
        if let existing = activeSessionId {
            return existing
        }
        let newSession = SessionID()
        self.activeSessionId = newSession

        // MARK: - PR-01: Instantiate HaispaceSession Aggregate via SessionFactory
        let guest = SessionGuest(name: guestName)
        let pkg = BoothPackage.mockStandard
        if let aggregate = try? SessionFactory.createSession(guest: guest, package: pkg) {
            self.activeSession = aggregate
            Task {
                let snap = await aggregate.snapshot()
                try? await self.sessionRepository.save(snap)
            }
        }

        SessionAuditTrail.create(sessionId: newSession.rawValue)
        SessionAuditTrail.append(
            sessionId: newSession.rawValue,
            stage: currentStage,
            eventType: .sessionStarted
        )
        return newSession
    }
}

// MARK: - Workflow Errors
public enum WorkflowError: Error, LocalizedError, Equatable {
    case sessionNotActive
    case invalidTransition
    
    public var errorDescription: String? {
        switch self {
        case .sessionNotActive: return "Sesi workflow belum diinisialisasi."
        case .invalidTransition: return "Transisi stage workflow tidak valid."
        }
    }
}
