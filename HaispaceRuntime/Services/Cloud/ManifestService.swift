// ManifestService.swift
// HaispaceRuntime — Services/Cloud
//
// Service penanggung jawab fetching & polling Manifest Konfigurasi dari Cloud Backend (GET /v1/manifests/latest).
// Mematuhinya aturan Session Pinning (ADR-016 Law 1 & Law 4) & Monotonic Manifest Versioning (ADR-017 Rule V-001).
//
// Ref: MANIFEST_CONTRACT_V1.md, ADR-016, ADR-017

import Foundation

public actor ManifestService {
    
    public static let shared = ManifestService()
    
    private let baseURL: URL
    private let session: URLSession
    private(set) public var currentLocalVersion: Int = 0
    
    public init(
        baseURL: URL = URL(string: "https://api.haispaceproject.my.id")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }
    
    /// Mengambil Manifest terbaru dari Cloud API menggunakan Device JWT
    public func fetchLatestManifest(deviceToken: String) async throws -> EventRuntimeResponse? {
        // Mengikuti spesifikasi E.6: GET /devices/me/event
        let endpoint = baseURL.appendingPathComponent("/devices/me/event")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(deviceToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            HaispaceLogger.warning("[ManifestService] Invalid HTTP Response", category: "cloud")
            return nil
        }
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            HaispaceLogger.warning("[ManifestService] Device Token Invalid or Revoked", category: "cloud")
            throw URLError(.userAuthenticationRequired)
        }
        
        guard httpResponse.statusCode == 200 else {
            HaispaceLogger.warning("[ManifestService] Server returned status code \(httpResponse.statusCode)", category: "cloud")
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let eventRuntime = try decoder.decode(EventRuntimeResponse.self, from: data)
        
        // Cek IDLE
        if eventRuntime.status == "IDLE" {
            HaispaceLogger.info("[ManifestService] Event is IDLE.", category: "cloud")
            return eventRuntime
        }
        
        guard let manifestVersion = eventRuntime.manifest?.version else { return eventRuntime }
        
        // Rule V-001: Hanya update jika manifestVersion Cloud > Local Version
        guard manifestVersion > currentLocalVersion else {
            HaispaceLogger.info("[ManifestService] Manifest versi \(manifestVersion) sudah ada di lokal", category: "cloud")
            return eventRuntime
        }
        
        self.currentLocalVersion = manifestVersion
        HaispaceLogger.info("[ManifestService] New Manifest Version \(manifestVersion) fetched", category: "cloud")
        return eventRuntime
    }
}

// MARK: - DTO Manifest Response (Strict Contract)

public struct EventRuntimeResponse: Codable, Sendable {
    public let status: String
    public let event: EventInfo?
    public let manifest: ManifestInfo?
    public let packages: [PackageInfo]?
    public let assets: [CloudAssetDTO]?
}

public struct EventInfo: Codable, Sendable {
    public let id: String
    public let name: String
    public let venue: String?
    public let scheduledDate: String?
}

public struct ManifestInfo: Codable, Sendable {
    public let id: String
    public let version: Int
    public let publishedAt: String?
}

public struct PackageInfo: Codable, Sendable {
    public let id: String
    public let name: String
    public let priceAmount: Int
    public let captureLimit: Int
    public let selectionLimit: Int
}

