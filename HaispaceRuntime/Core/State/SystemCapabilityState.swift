// CapabilityManager.swift
// HaispaceRuntime — Core/State

import Foundation

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
        BootstrapObservabilityLogger.shared.logEvent("CAPABILITY UPDATED: Camera -> \(status.rawValue)")
    }
    
    public func updatePrinter(status: CapabilityStatus) {
        state.printer = status
        BootstrapObservabilityLogger.shared.logEvent("CAPABILITY UPDATED: Printer -> \(status.rawValue)")
    }
    
    public func updateNetwork(status: CapabilityStatus) {
        state.network = status
        BootstrapObservabilityLogger.shared.logEvent("CAPABILITY UPDATED: Network -> \(status.rawValue)")
    }
    
    public func updateStorage(status: CapabilityStatus) {
        state.storage = status
        BootstrapObservabilityLogger.shared.logEvent("CAPABILITY UPDATED: Storage -> \(status.rawValue)")
    }
    
    public func performDiscovery() async {
        // Simulasi discovery hardware & OS
        // Dalam implementasi nyata, ini mengecek space storage, reachability, dll.
        updateNetwork(status: .available)
        updateStorage(status: .available)
        
        // Printer & Camera kita asumsikan unavailable sampai di-connect
        updatePrinter(status: .unavailable)
        updateCamera(status: .unavailable)
    }
}
