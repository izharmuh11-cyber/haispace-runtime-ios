// RuntimeNodeServices.swift
// HaispaceRuntime — Services/Cloud

import Foundation
import OSLog

// MARK: - DTOs

public struct RuntimeTimeResponse: Codable, Sendable {
    public let serverTime: Date
}

public struct RuntimeCapabilitiesResponse: Codable, Sendable {
    public let requiredCapabilities: [String]
    public let latestClientVersion: String
}

public struct RuntimeManifestResponse: Codable, Sendable {
    public let version: Int
    public let activeThemeId: String
    public let activePackageIds: [String]
}

public struct HeartbeatRequest: Codable, Sendable {
    public let timestamp: Date
    public let status: String
}

public struct HeartbeatResponse: Codable, Sendable {
    public let acknowledged: Bool
}

// MARK: - Device Registration Service

public final class DeviceRegistrationService: @unchecked Sendable {
    public static let shared = DeviceRegistrationService()
    private init() {}
    
    // Toggle ini ke false saat backend sungguhan sudah online
    private let useMock = true
    
    public func fetchServerTime() async throws -> RuntimeTimeResponse {
        if useMock { return RuntimeTimeResponse(serverTime: Date()) }
        return try await HSPCloudClient.shared.request(endpoint: "/runtime/time", requiresAuth: false)
    }
    
    public func fetchCapabilities() async throws -> RuntimeCapabilitiesResponse {
        if useMock { return RuntimeCapabilitiesResponse(requiredCapabilities: ["camera", "network", "storage", "p2p", "printer"], latestClientVersion: "1.0.0") }
        return try await HSPCloudClient.shared.request(endpoint: "/runtime/capabilities", requiresAuth: true)
    }
}

// MARK: - Manifest Service

public final class ManifestService: @unchecked Sendable {
    public static let shared = ManifestService()
    private init() {}
    
    private let useMock = true
    
    public func fetchManifest() async throws -> RuntimeManifestResponse {
        if useMock { return RuntimeManifestResponse(version: 1, activeThemeId: "default", activePackageIds: ["pkg-1", "pkg-2"]) }
        return try await HSPCloudClient.shared.request(endpoint: "/runtime/manifest", requiresAuth: true)
    }
}

// MARK: - Heartbeat Service

@MainActor
public final class HeartbeatService {
    public static let shared = HeartbeatService()
    
    private var heartbeatTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "id.haispaceproject.runtime", category: "Heartbeat")
    private let useMock = true
    
    private init() {}
    
    public func startPinging(intervalSeconds: TimeInterval = 30) {
        stopPinging()
        
        heartbeatTask = Task {
            while !Task.isCancelled {
                do {
                    if useMock {
                        RuntimeTimelineLogger.shared.logEvent("HEARTBEAT", payload: "ACK (Mock)")
                    } else {
                        let payload = HeartbeatRequest(timestamp: Date(), status: "HEALTHY")
                        let data = try JSONEncoder().encode(payload)
                        let _: HeartbeatResponse = try await HSPCloudClient.shared.request(
                            endpoint: "/runtime/heartbeat",
                            method: "POST",
                            body: data,
                            requiresAuth: true
                        )
                        RuntimeTimelineLogger.shared.logEvent("HEARTBEAT", payload: "ACK")
                    }
                } catch {
                    logger.error("Heartbeat failed: \(error.localizedDescription)")
                    RuntimeTimelineLogger.shared.logEvent("HEARTBEAT_FAILED", payload: error.localizedDescription)
                }
                
                try? await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
            }
        }
    }
    
    public func stopPinging() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }
}
