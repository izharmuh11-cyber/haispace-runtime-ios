// P2PCapabilityService.swift
// HaispaceRuntime — Core/Capabilities/P2P

import Foundation

public actor P2PCapabilityService: P2PCapabilityProtocol {
    public static let shared = P2PCapabilityService()
    
    private let controller = P2PSessionController()
    
    private var health = P2PHealth(status: .healthy, isNetworkConnected: true, isPeerPaired: false)
    private var metrics = P2PMetrics()
    
    public var healthSnapshot: P2PHealth {
        get { return health }
    }
    
    public var metricsSnapshot: P2PMetrics {
        get { return metrics }
    }
    
    private init() {}
    
    public func prepare(configuration: P2PConfiguration) async throws {
        await RuntimeTimelineLogger.shared.logEvent("P2P PREPARE", payload: "Configured")
        try await controller.startAdvertising(configuration: configuration)
    }
    
    public func startSession(sessionId: SessionID) async throws -> P2PPeerInfo {
        await RuntimeTimelineLogger.shared.logEvent("P2P SESSION START", payload: sessionId.rawValue)
        let peer = try await controller.waitForPeerConnection()
        return peer
    }
    
    public func stopSession() async {
        await RuntimeTimelineLogger.shared.logEvent("P2P SESSION STOP")
        controller.disconnect()
    }
    
    public func requestTransfer(transferId: TransferID, payloadPath: String) async throws -> P2PTransferResult {
        await RuntimeTimelineLogger.shared.logEvent("P2P TRANSFER REQ", payload: payloadPath)
        return P2PTransferResult(transferId: transferId, status: .completed, bytesTransferred: 1024, durationMs: 50)
    }
    
    public func requestResume(transferId: TransferID, fromChunkIndex: UInt32) async throws -> P2PTransferResult {
        return P2PTransferResult(transferId: transferId, status: .completed, bytesTransferred: 1024, durationMs: 50)
    }
}
