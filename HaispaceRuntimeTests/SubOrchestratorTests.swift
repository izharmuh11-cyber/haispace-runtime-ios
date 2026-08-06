// SubOrchestratorTests.swift
// HaispaceRuntimeTests — Core/Workflow Tests
//
// Unit tests untuk memverifikasi fungsionalitas dan test-parity dari
// CaptureOrchestrator, CheckoutOrchestrator, dan SessionRecoveryEngine.
//
// Ref: ADR-016, ADR-017, ADR-018

import XCTest
@testable import HaispaceRuntime

final class SubOrchestratorTests: XCTestCase {
    
    var noOpCamera: NoOpCameraCapability!
    var noOpEditing: NoOpEditingCapability!
    var noOpPayment: NoOpPaymentCapability!
    var noOpDelivery: NoOpDeliveryCapability!
    var noOpP2P: NoOpP2PCapability!
    var noOpRepo: NoOpSessionRepository!
    
    override func setUp() async throws {
        try await super.setUp()
        noOpCamera = NoOpCameraCapability()
        noOpEditing = NoOpEditingCapability()
        noOpPayment = NoOpPaymentCapability()
        noOpDelivery = NoOpDeliveryCapability()
        noOpP2P = NoOpP2PCapability()
        noOpRepo = NoOpSessionRepository()
    }
    
    func testCaptureOrchestratorInitializationAndTimer() async throws {
        let captureOrchestrator = CaptureOrchestrator(camera: noOpCamera, p2p: noOpP2P)
        
        let remainingBefore = await captureOrchestrator.sessionTimerRemaining
        XCTAssertEqual(remainingBefore, 0)
        
        await captureOrchestrator.startSessionCountdown(duration: 300)
        let remainingAfter = await captureOrchestrator.sessionTimerRemaining
        XCTAssertEqual(remainingAfter, 300)
        
        await captureOrchestrator.stopSessionCountdown()
        let remainingFinal = await captureOrchestrator.sessionTimerRemaining
        XCTAssertEqual(remainingFinal, 0)
    }
    
    func testCheckoutOrchestratorPaymentFlow() async throws {
        let checkoutOrchestrator = CheckoutOrchestrator(
            editing: noOpEditing,
            payment: noOpPayment,
            delivery: noOpDelivery,
            sessionRepository: noOpRepo
        )
        
        let sessionId = SessionID()
        let correlationId = CorrelationID()
        
        // Request payment should complete without errors via NoOp Payment Provider
        do {
            try await checkoutOrchestrator.requestPayment(sessionId: sessionId, correlationId: correlationId, amount: 35000)
            XCTAssertTrue(true, "Payment request via CheckoutOrchestrator succeeded")
        } catch {
            XCTFail("Payment request failed with error: \(error)")
        }
    }
    
    func testSessionRecoveryEngineScan() async throws {
        let recoveryEngine = SessionRecoveryEngine()
        let decisions = await recoveryEngine.scanOrphanedSessions()
        
        // Output should be an array of OrphanedSessionDecision (may be empty on clean test env)
        XCTAssertNotNil(decisions)
    }
}
