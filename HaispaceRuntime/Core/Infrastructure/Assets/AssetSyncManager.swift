import Foundation

public enum AssetState: String {
    case downloading = "DOWNLOADING"
    case validatedAndReady = "VALIDATED_AND_READY"
    case integrityFailed = "INTEGRITY_FAILED"
}

public protocol NetworkClient {
    func downloadFile(from url: URL, to destination: URL) async throws
}

public struct ManifestAssetEntry {
    public let id: String
    public let downloadUrl: URL
    public let expectedChecksum: String
}

/// Orchestrates the downloading and cryptographic verification of .hspasset packages.
public class AssetSyncManager {
    
    private let networkClient: NetworkClient
    private let localStorageDirectory: URL
    
    // Tracks the current readiness state of assets
    public private(set) var assetStates: [String: AssetState] = [:]
    
    public init(networkClient: NetworkClient, localStorageDirectory: URL) {
        self.networkClient = networkClient
        self.localStorageDirectory = localStorageDirectory
    }
    
    /// Pre-caches all assets defined in the event manifest.
    /// Kiosk should block user interaction until all assets are validatedAndReady.
    public func sync(assets: [ManifestAssetEntry]) async {
        
        for asset in assets {
            assetStates[asset.id] = .downloading
            
            let destinationURL = localStorageDirectory.appendingPathComponent("\(asset.id).hspasset")
            
            do {
                // Differential logic: Only download if it doesn't exist or checksum is wrong
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    do {
                        try AssetChecksumValidator.validate(fileURL: destinationURL, expectedChecksum: asset.expectedChecksum)
                        self.assetStates[asset.id] = .validatedAndReady
                        continue // Skip download, already validated
                    } catch {
                        // Checksum failed, delete corrupted file and proceed to download
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                }
                
                // Download
                try await networkClient.downloadFile(from: asset.downloadUrl, to: destinationURL)
                
                // Verify strict integrity post-download
                try AssetChecksumValidator.validate(fileURL: destinationURL, expectedChecksum: asset.expectedChecksum)
                
                self.assetStates[asset.id] = .validatedAndReady
                
            } catch {
                self.assetStates[asset.id] = .integrityFailed
                print("Asset Sync Failed for \(asset.id): \(error.localizedDescription)")
            }
        }
    }
    
    /// Checks if the entire manifest is ready for offline operation
    public var isReadyForOfflineOperation: Bool {
        return assetStates.values.allSatisfy { $0 == .validatedAndReady } && !assetStates.isEmpty
    }
}
