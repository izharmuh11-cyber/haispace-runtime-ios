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
        logger.auditLog(step: "App Launch", status: "SUCCESS")
        logger.auditLog(step: "Bootstrap Started", status: "SUCCESS")
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
            let deviceToken = keyStore.getDeviceToken()
            
            var debugEventId: String? = nil
            if deviceToken == nil {
                debugEventId = UserDefaults.standard.string(forKey: "DEBUG_EVENT_ID") ?? "latest"
            }
            
            if deviceToken != nil || debugEventId != nil {
                if deviceToken != nil {
                    logger.auditLog(step: "Device JWT Loaded", status: "SUCCESS")
                } else {
                    logger.auditLog(step: "Device JWT Missing", status: "INFO", detail: "Using Debug Event ID")
                    logger.logEvent("JWT MISSING - USING DEBUG EVENT ID: \(debugEventId ?? "")")
                }
                
                if let eventRuntime = try await manifestService.fetchLatestManifest(deviceToken: deviceToken, debugEventId: debugEventId) {
                    logger.logEvent("MANIFEST READY", payload: "v\(eventRuntime.version)")
                    
                    // SYNC TEMPLATES (Phase 4)
                    if let templates = eventRuntime.templates, !templates.isEmpty {
                        await TemplateStore.shared.ingest(templates: templates)
                        logger.logEvent("TEMPLATE SYNC COMPLETED", payload: "\(templates.count) templates")
                        await logger.auditLog(step: "Template Sync", status: "SUCCESS", detail: "\(templates.count) templates")
                    }
                    
                    // SYNC ASSETS
                    if let cloudAssets = eventRuntime.assets, !cloudAssets.isEmpty {
                        logger.logEvent("ASSET SYNC STARTED", payload: "\(cloudAssets.count) assets")
                        let store = LocalAssetStore()
                        let syncService = AssetSyncService(store: store)
                        try await syncService.syncAssets(from: cloudAssets)
                        logger.logEvent("ASSET SYNC COMPLETED")
                    }
                }
            } else {
                logger.auditLog(step: "Device JWT Loaded", status: "FAILED", detail: "Token missing")
                logger.logEvent("DEVICE TOKEN MISSING - SKIP MANIFEST")
            }
            
            // 5. HEARTBEAT START
            logger.auditLog(step: "Heartbeat Request", status: "SUCCESS")
            // HeartbeatService diatur di level App/Orchestrator, bootstrap hanya menandai ready
            
            // 6. READY
            updateState(.ready)
            logger.logEvent("STATE READY")
            logger.auditLog(step: "Bootstrap Ready", status: "SUCCESS")
            
        } catch {
            updateState(.error)
            logger.auditLog(step: "Bootstrap Sequence", status: "FAILED", detail: error.localizedDescription)
            logger.logEvent("BOOT ERROR", payload: error.localizedDescription)
        }
    }
}
