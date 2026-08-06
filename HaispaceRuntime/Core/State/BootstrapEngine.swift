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
    private let regService = DeviceRegistrationService.shared
    private let manifestService = ManifestService.shared
    
    public init(capabilityManager: SystemCapabilityState) {
        self.capabilityManager = capabilityManager
    }
    
    private func updateState(_ newState: BootstrapState) {
        self.currentState = newState
    }
    
    public func startBootstrapSequence() async {
        let logger = RuntimeTimelineLogger.shared
        logger.logEvent("BOOT STARTED")
        
        do {
            // 1. CAPABILITY DISCOVERY
            updateState(.capabilityDiscovery)
            logger.logEvent("CAPABILITY DISCOVERY STARTED")
            await capabilityManager.performDiscovery()
            let caps = await capabilityManager.state
            logger.logEvent("CAPABILITIES LOADED", payload: "[Camera: \(caps.camera), Printer: \(caps.printer), Net: \(caps.network)]")
            
            // 2. CLOCK SYNC
            updateState(.clockSync)
            logger.logEvent("CLOCK SYNC STARTED")
            let timeRes = try await regService.fetchServerTime()
            logger.logEvent("CLOCK SYNC SUCCESS", payload: "ServerTime = \(timeRes.serverTime)")
            
            // 3. CAPABILITIES / DEVICE REGISTRATION
            updateState(.deviceRegistration)
            logger.logEvent("DEVICE REGISTRATION STARTED")
            let capRes = try await regService.fetchCapabilities()
            logger.logEvent("DEVICE REGISTERED", payload: "Latest Client Version: \(capRes.latestClientVersion)")
            
            // 4. MANIFEST DOWNLOAD & ASSET SYNC
            updateState(.manifestDownload)
            logger.logEvent("MANIFEST DOWNLOAD STARTED")
            
            let keyStore = DeviceKeyStore()
            if let token = keyStore.getDeviceToken() {
                if let eventRuntime = try await manifestService.fetchLatestManifest(deviceToken: token) {
                    if eventRuntime.status == "IDLE" {
                        logger.logEvent("EVENT IS IDLE")
                    } else {
                        logger.logEvent("MANIFEST READY", payload: "v\(eventRuntime.manifest?.version ?? 0)")
                        
                        // SYNC ASSETS
                        if let cloudAssets = eventRuntime.assets, !cloudAssets.isEmpty {
                            logger.logEvent("ASSET SYNC STARTED", payload: "\(cloudAssets.count) assets")
                            let store = LocalAssetStore()
                            let syncService = AssetSyncService(store: store)
                            try await syncService.syncAssets(from: cloudAssets)
                            logger.logEvent("ASSET SYNC COMPLETED")
                        }
                    }
                }
            } else {
                logger.logEvent("DEVICE TOKEN MISSING - SKIP MANIFEST")
            }
            
            // 5. HEARTBEAT START
            HeartbeatService.shared.startPinging()
            
            // 6. READY
            updateState(.ready)
            logger.logEvent("STATE READY")
            
        } catch {
            updateState(.error)
            logger.logEvent("BOOT ERROR", payload: error.localizedDescription)
        }
    }
}
