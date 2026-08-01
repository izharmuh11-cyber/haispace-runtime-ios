// BootstrapAPI.swift
// HaispaceRuntime — Services/Cloud

import Foundation

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

public final class BootstrapAPI: @unchecked Sendable {
    public static let shared = BootstrapAPI()
    private init() {}
    
    public func fetchServerTime() async throws -> RuntimeTimeResponse {
        // Return dummy mock response if server is unreachable during development
        // try await HSPCloudClient.shared.request(endpoint: "/runtime/time", requiresAuth: false)
        return RuntimeTimeResponse(serverTime: Date())
    }
    
    public func fetchCapabilities() async throws -> RuntimeCapabilitiesResponse {
        // try await HSPCloudClient.shared.request(endpoint: "/runtime/capabilities", requiresAuth: true)
        return RuntimeCapabilitiesResponse(requiredCapabilities: ["camera", "network", "storage"], latestClientVersion: "1.0.0")
    }
    
    public func fetchManifest() async throws -> RuntimeManifestResponse {
        // try await HSPCloudClient.shared.request(endpoint: "/runtime/manifest", requiresAuth: true)
        return RuntimeManifestResponse(version: 1, activeThemeId: "default", activePackageIds: ["pkg-1", "pkg-2"])
    }
}
