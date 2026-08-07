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
    
    /// Mengambil Manifest terbaru dari Cloud API menggunakan Device JWT atau Event ID publik di mode Debug
    public func fetchLatestManifest(deviceToken: String?, debugEventId: String? = nil) async throws -> EventRuntimeResponse? {
        let logger = await RuntimeTimelineLogger.shared
        await logger.auditLog(step: "Manifest Request", status: "START")
        
        let endpoint: URL
        var request: URLRequest
        
        if let token = deviceToken {
            // Mengikuti spesifikasi E.6: GET /devices/me/event
            endpoint = baseURL.appendingPathComponent("/devices/me/event")
            request = URLRequest(url: endpoint)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if let eventId = debugEventId {
            // Endpoint DDD Runtime Manifest resmi
            if eventId == "latest" {
                endpoint = baseURL.appendingPathComponent("/v1/runtime/manifest")
            } else {
                endpoint = URL(string: "\(baseURL.absoluteString)/v1/runtime/manifest?eventId=\(eventId)")!
            }
            request = URLRequest(url: endpoint)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
        } else {
            await logger.auditLog(step: "Manifest Request", status: "FAILED", detail: "No Token or Event ID")
            return nil
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            await logger.auditLog(step: "Manifest Request", status: "FAILED", detail: "Invalid HTTP Response")
            HaispaceLogger.warning("[ManifestService] Invalid HTTP Response", category: "cloud")
            return nil
        }
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            await logger.auditLog(step: "Manifest Request", status: "FAILED", detail: "Token Invalid/Revoked")
            HaispaceLogger.warning("[ManifestService] Device Token Invalid or Revoked", category: "cloud")
            throw URLError(.userAuthenticationRequired)
        }
        
        guard httpResponse.statusCode == 200 else {
            await logger.auditLog(step: "Manifest Request", status: "FAILED", detail: "HTTP \(httpResponse.statusCode)")
            HaispaceLogger.warning("[ManifestService] Server returned status code \(httpResponse.statusCode)", category: "cloud")
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let eventRuntime = try decoder.decode(EventRuntimeResponse.self, from: data)
        await logger.auditLog(step: "Manifest Request", status: "SUCCESS")
        
        await logger.auditLog(step: "Event Status", status: "SUCCESS", detail: "ACTIVE")
        
        let manifestVersion = eventRuntime.version
        
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
    public let manifestId: String
    public let version: Int
    public let eventId: String
    public let eventName: String
    public let publishedAt: String?
    public let assets: [CloudAssetDTO]?
    public let templates: [TemplateManifest]?
}

