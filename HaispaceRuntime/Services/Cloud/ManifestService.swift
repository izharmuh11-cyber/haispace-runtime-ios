// ManifestService.swift
// HaispaceRuntime — Services/Cloud
//
// Service penanggung jawab fetching & polling Manifest Konfigurasi dari Cloud Backend (GET /v1/manifests/latest).
// Mematuhinya aturan Session Pinning (ADR-016 Law 1 & Law 4) & Monotonic Manifest Versioning (ADR-017 Rule V-001).
//
// Ref: MANIFEST_CONTRACT_V1.md, ADR-016, ADR-017

import Foundation

public actor ManifestService {
    
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
    
    /// Mengambil Manifest terbaru dari Cloud API jika `manifestVersion` Cloud > Local.
    public func fetchLatestManifest(boothId: String) async throws -> ManifestResponse? {
        let endpoint = baseURL.appendingPathComponent("/v1/manifests/latest")
            .appending(queryItems: [URLQueryItem(name: "boothId", value: boothId)])
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("booth-kiosk-runtime", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            HaispaceLogger.warning("[ManifestService] Server returned non-200 status code", category: "cloud")
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let manifest = try decoder.decode(ManifestResponse.self, from: data)
        
        // Rule V-001: Hanya terima jika manifestVersion Cloud > Local Version
        guard manifest.manifestVersion > currentLocalVersion else {
            HaispaceLogger.info("[ManifestService] Manifest versi \(manifest.manifestVersion) sudah ada di lokal", category: "cloud")
            return nil
        }
        
        self.currentLocalVersion = manifest.manifestVersion
        HaispaceLogger.info("[ManifestService] New Manifest Version \(manifest.manifestVersion) fetched for Event: \(manifest.eventName)", category: "cloud")
        return manifest
    }
}

// MARK: - DTO Manifest Response (Strict Contract)

public struct ManifestResponse: Codable, Sendable {
    public let manifestSchemaVersion: Int
    public let manifestVersion: Int
    public let eventId: String
    public let eventName: String
    public let boothId: String
    public let publishedAt: Date
    public let packages: [ManifestPackage]
    public let allowedFrameIds: [String]
    public let assets: [ManifestAsset]
}

public struct ManifestPackage: Codable, Sendable {
    public let packageId: String
    public let packageName: String
    public let price: Int
    public let captureLimit: Int
    public let minSelectionCount: Int
    public let maxSelectionCount: Int
    public let supportedFrameIds: [String]
}

public struct ManifestAsset: Codable, Sendable {
    public let assetId: String
    public let assetType: String
    public let checksum: String
    public let downloadUrl: String
    public let fileSizeBytes: Int64
    public let minRuntimeVersion: String
}
