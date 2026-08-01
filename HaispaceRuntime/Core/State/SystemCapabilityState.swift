// CapabilityManager.swift
// HaispaceRuntime — Core/State

import Foundation
import Observation
import Network

public enum CapabilityStatus: String, Codable, Sendable {
    case available
    case unavailable
    case degraded
    case error
    case unknown
}

public struct CapabilityState: Codable, Sendable {
    public var camera: CapabilityStatus = .unknown
    public var printer: CapabilityStatus = .unknown
    public var network: CapabilityStatus = .unknown
    public var storage: CapabilityStatus = .unknown
}

@MainActor
public final class SystemCapabilityState: ObservableObject, @unchecked Sendable {
    @Published public private(set) var state = CapabilityState()
    
    public init() {}
    
    public func updateCamera(status: CapabilityStatus) {
        state.camera = status
        RuntimeTimelineLogger.shared.logEvent("CAPABILITY UPDATED", payload: "Camera -> \(status.rawValue)")
    }
    
    public func updatePrinter(status: CapabilityStatus) {
        state.printer = status
        RuntimeTimelineLogger.shared.logEvent("CAPABILITY UPDATED", payload: "Printer -> \(status.rawValue)")
    }
    
    public func updateNetwork(status: CapabilityStatus) {
        state.network = status
        RuntimeTimelineLogger.shared.logEvent("CAPABILITY UPDATED", payload: "Network -> \(status.rawValue)")
    }
    
    public func updateStorage(status: CapabilityStatus) {
        state.storage = status
        RuntimeTimelineLogger.shared.logEvent("CAPABILITY UPDATED", payload: "Storage -> \(status.rawValue)")
    }
    
    public func performDiscovery() async {
        // 1. Network Discovery via Network Framework
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkDiscovery")
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                if path.status == .satisfied {
                    self?.updateNetwork(status: .available)
                } else {
                    self?.updateNetwork(status: .unavailable)
                }
            }
        }
        monitor.start(queue: queue)
        
        // 2. Storage Check (Simulated for now)
        updateStorage(status: .available)
        
        // 3. Printer & Camera & P2P (Simulated M-006: Unavailable until actual drivers connect)
        updatePrinter(status: .unavailable)
        updateCamera(status: .unavailable)
        
        // Catat tambahan P2P (meski kita belum nambah property di state)
        RuntimeTimelineLogger.shared.logEvent("CAPABILITY UPDATED", payload: "P2P -> unavailable")
    }
}
