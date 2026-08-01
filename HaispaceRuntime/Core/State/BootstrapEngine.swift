// BootstrapEngine.swift
// HaispaceRuntime — Core/State

import Foundation

public enum BootstrapState: String, Sendable {
    case pending
    case capabilityDiscovery
    case clockSync
    case deviceRegistration
    case manifestDownload
    case ready
    case error
}

@MainActor
public final class BootstrapEngine: ObservableObject, @unchecked Sendable {
    @Published public private(set) var currentState: BootstrapState = .pending
    
    public let capabilityManager: SystemCapabilityState
    private let api = BootstrapAPI.shared
    
    public init(capabilityManager: SystemCapabilityState) {
        self.capabilityManager = capabilityManager
    }
    
    private func updateState(_ newState: BootstrapState) {
        self.currentState = newState
    }
    
    public func startBootstrapSequence() async {
        let logger = BootstrapObservabilityLogger.shared
        logger.logEvent("BOOT STARTED")
        
        do {
            // 1. CAPABILITY DISCOVERY
            updateState(.capabilityDiscovery)
            logger.logEvent("CAPABILITY DISCOVERY STARTED")
            await capabilityManager.performDiscovery()
            let caps = await capabilityManager.state
            logger.logEvent("CAPABILITIES LOADED: [Camera: \(caps.camera), Printer: \(caps.printer), Net: \(caps.network)]")
            
            // 2. CLOCK SYNC
            updateState(.clockSync)
            logger.logEvent("CLOCK SYNC STARTED")
            let timeRes = try await api.fetchServerTime()
            logger.logEvent("CLOCK SYNC SUCCESS: ServerTime = \(timeRes.serverTime)")
            
            // 3. CAPABILITIES / DEVICE REGISTRATION
            updateState(.deviceRegistration)
            logger.logEvent("DEVICE REGISTRATION STARTED")
            let capRes = try await api.fetchCapabilities()
            logger.logEvent("DEVICE REGISTERED. Latest Client Version: \(capRes.latestClientVersion)")
            
            // 4. MANIFEST DOWNLOAD
            updateState(.manifestDownload)
            logger.logEvent("MANIFEST DOWNLOAD STARTED")
            let manifest = try await api.fetchManifest()
            logger.logEvent("MANIFEST READY (v\(manifest.version))")
            
            // 5. READY
            updateState(.ready)
            logger.logEvent("STATE READY")
            
        } catch {
            updateState(.error)
            logger.logEvent("BOOT ERROR: \(error.localizedDescription)")
        }
    }
}
