// CheckoutOrchestrator.swift
// HaispaceRuntime — Core/Workflow
//
// Sub-Orchestrator khusus untuk domain Checkout, Export, Payment & Delivery.
// Mengisolasi Frame Composite Export, Payment Gateway Interactions, dan Delivery Queue Dispatch.
//
// Ref: ADR-016, ADR-017, ADR-018

import Foundation

public actor CheckoutOrchestrator {
    
    // MARK: - Dependencies
    public let editing: EditingCapabilityProtocol
    public let payment: PaymentCapabilityProtocol
    public let delivery: DeliveryCapabilityProtocol
    public let sessionRepository: SessionRepositoryProtocol
    
    // MARK: - Initializer
    public init(
        editing: EditingCapabilityProtocol,
        payment: PaymentCapabilityProtocol,
        delivery: DeliveryCapabilityProtocol,
        sessionRepository: SessionRepositoryProtocol
    ) {
        self.editing = editing
        self.payment = payment
        self.delivery = delivery
        self.sessionRepository = sessionRepository
    }
    
    // MARK: - Template Selection & Export
    
    /// Memproses ekspor komposit frame foto hasil capture.
    public func processTemplateExport(
        frameId: String,
        sessionId: SessionID,
        correlationId: CorrelationID
    ) async throws -> (photoId: PhotoID, outputReference: String) {
        let capturedPhotos = await CapturedPhotoStore.shared.capturedPhotos
        guard let firstPhoto = capturedPhotos.first,
              let sourcePath = firstPhoto.writeToTempFile() else {
            throw WorkflowError.sessionNotActive
        }
        
        let photoRef = PhotoReference(photoId: PhotoID(rawValue: firstPhoto.id), sourcePath: sourcePath)
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let frameAssetPath = cachesDir.appendingPathComponent("HaispaceFrames/\(frameId).png").path
        
        let editingConfig = EditingConfiguration(
            frame: FrameReference(frameId: frameId, assetPath: frameAssetPath)
        )
        try await editing.prepare(sessionId: sessionId, configuration: editingConfig)
        
        let exportResult = try await editing.requestExport(photoInput: photoRef.sourcePath, correlationId: correlationId)
        return (exportResult.photoId, exportResult.outputReference)
    }
    
    // MARK: - Payment & Delivery Processing
    
    /// Mengajukan permintaan pembayaran QRIS/Kasir.
    public func requestPayment(
        sessionId: SessionID,
        correlationId: CorrelationID,
        amount: Int = 35000
    ) async throws {
        try await payment.prepare(configuration: PaymentConfiguration())
        _ = try await payment.requestPayment(
            sessionId: sessionId,
            correlationId: correlationId,
            amount: PaymentAmount(amountValue: Double(amount), method: .localQRIS),
            method: .localQRIS
        )
    }
    
    /// Mengonfirmasi pembayaran sukses dan memperbarui Shadow Aggregate.
    public func confirmPaymentSuccess(
        sessionId: SessionID,
        activeSession: HaispaceSession?
    ) async throws -> String {
        let txnId = UUID().uuidString
        if let aggregate = activeSession {
            try? await aggregate.acceptPayment(
                localTransactionId: txnId,
                amount: 35000,
                method: .qris
            )
            let snap = await aggregate.snapshot()
            try? await sessionRepository.save(snap)
        }
        return txnId
    }
    
    /// Menjadwalkan pengiriman cetak / QR.
    public func dispatchDelivery(
        sessionId: SessionID,
        correlationId: CorrelationID,
        photoId: PhotoID,
        outputRef: String
    ) async throws {
        try await delivery.prepare(configuration: DeliveryConfiguration())
        _ = try await delivery.requestDelivery(
            sessionId: sessionId,
            correlationId: correlationId,
            photoId: photoId,
            assetPath: outputRef,
            channel: .localBonjourWiFiServer
        )
    }
}
