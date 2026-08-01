// P2PSessionController.swift
// HaispaceRuntime — Core/Capabilities/P2P

import Foundation
import MultipeerConnectivity
import OSLog
import UIKit

public actor P2PSessionController: NSObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate {
    
    private let peerID = MCPeerID(displayName: "Haispace Kiosk (\(UIDevice.current.name))")
    private let serviceType = "haispace-p2p"
    
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    
    private let logger = Logger(subsystem: "id.haispaceproject.runtime", category: "P2PController")
    private var connectedPeers: Set<MCPeerID> = []
    
    public override init() {
        self.session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        self.session.delegate = self
    }
    
    public func startAdvertising() {
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        logger.info("Started advertising P2P service: \(self.serviceType)")
    }
    
    public func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        session.disconnect()
        connectedPeers.removeAll()
        logger.info("Stopped advertising P2P service.")
    }
    
    public func sendTestPayload(to peer: MCPeerID) throws {
        let payload = "PING_\(Date().timeIntervalSince1970)".data(using: .utf8)!
        try session.send(payload, toPeers: [peer], with: .reliable)
    }
    
    public var hasConnectedPeers: Bool {
        return !connectedPeers.isEmpty
    }
    
    // MARK: - MCSessionDelegate
    
    nonisolated public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task {
            await handlePeerStateChange(peerID: peerID, state: state)
        }
    }
    
    private func handlePeerStateChange(peerID: MCPeerID, state: MCSessionState) {
        switch state {
        case .connected:
            connectedPeers.insert(peerID)
            logger.info("Peer connected: \(peerID.displayName)")
            RuntimeTimelineLogger.shared.logEvent("P2P CONNECTED", payload: peerID.displayName)
            
        case .notConnected:
            connectedPeers.remove(peerID)
            logger.info("Peer disconnected: \(peerID.displayName)")
            RuntimeTimelineLogger.shared.logEvent("P2P DISCONNECTED", payload: peerID.displayName)
            
        case .connecting:
            logger.info("Peer connecting: \(peerID.displayName)")
            
        @unknown default:
            break
        }
    }
    
    nonisolated public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {}
    nonisolated public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    
    // MARK: - MCNearbyServiceAdvertiserDelegate
    
    nonisolated public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task {
            await handleInvitation(from: peerID, handler: invitationHandler)
        }
    }
    
    private func handleInvitation(from peer: MCPeerID, handler: @escaping (Bool, MCSession?) -> Void) {
        logger.info("Accepting invitation from: \(peer.displayName)")
        RuntimeTimelineLogger.shared.logEvent("P2P INVITATION ACCEPTED", payload: peer.displayName)
        handler(true, self.session)
    }
}
