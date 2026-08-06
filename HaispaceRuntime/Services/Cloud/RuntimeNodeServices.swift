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

// End of file
