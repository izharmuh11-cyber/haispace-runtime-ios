import Foundation
import CryptoKit

public enum AssetSyncError: Error {
    case invalidURL
    case downloadFailed
    case checksumMismatch
}

public class AssetSyncService {
    private let store: LocalAssetStoreProtocol
    private let urlSession: URLSession
    
    public init(store: LocalAssetStoreProtocol, urlSession: URLSession = .shared) {
        self.store = store
        self.urlSession = urlSession
    }
    
    /// Fungsi utama untuk sinkronisasi sekumpulan CloudAsset ke lokal.
    /// Menggunakan delta update: Jika checksum cocok, tidak diunduh.
    public func syncAssets(from cloudAssets: [CloudAssetDTO]) async throws {
        // Gunakan task group untuk concurrent downloads
        try await withThrowingTaskGroup(of: Void.self) { group in
            for cloudAsset in cloudAssets {
                group.addTask {
                    try await self.syncSingleAsset(cloudAsset)
                }
            }
            // Tunggu semua selesai
            for try await _ in group { }
        }
    }
    
    private func syncSingleAsset(_ cloudAsset: CloudAssetDTO) async throws {
        // Cek apakah sudah ada di lokal
        if let local = store.getAsset(id: cloudAsset.assetId) {
            // Delta update: Cek kesamaan checksum
            if local.checksum == cloudAsset.checksum {
                // Checksum cocok, tidak perlu download ulang
                await RuntimeTimelineLogger.shared.auditLog(step: "Asset Sync", status: "CACHE_HIT", detail: "\(cloudAsset.assetId)")
                return
            }
        }
        
        await RuntimeTimelineLogger.shared.auditLog(step: "Asset Sync", status: "CACHE_MISS", detail: "\(cloudAsset.assetId)")
        
        // Memerlukan unduhan
        guard let urlString = cloudAsset.downloadUrl, let url = URL(string: urlString) else {
            throw AssetSyncError.invalidURL
        }
        
        let (tempURL, response) = try await urlSession.download(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AssetSyncError.downloadFailed
        }
        
        // Hitung SHA256 dari file yang diunduh
        let fileData = try Data(contentsOf: tempURL)
        let hash = SHA256.hash(data: fileData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        // Verifikasi checksum (jika Cloud mengirimkan checksum)
        if let expectedChecksum = cloudAsset.checksum, !expectedChecksum.isEmpty {
            // Jika backend menambahkan prefix seperti 'sha256:', bersihkan dulu (opsional).
            // Asumsi checksum dari backend berupa hex string murni.
            let cleanExpected = expectedChecksum.replacingOccurrences(of: "sha256:", with: "").lowercased()
            if hashString != cleanExpected {
                await RuntimeTimelineLogger.shared.auditLog(step: "Checksum Validation", status: "FAILED", detail: "Mismatch for \(cloudAsset.assetId)")
                throw AssetSyncError.checksumMismatch
            }
        }
        await RuntimeTimelineLogger.shared.auditLog(step: "Checksum Validation", status: "SUCCESS", detail: "\(cloudAsset.assetId)")
        
        // Tentukan ekstensi dari URL aslinya
        let ext = url.pathExtension.isEmpty ? "bin" : url.pathExtension
        let fileName = "\(cloudAsset.assetId).\(ext)"
        let finalRelativePath = "\(cloudAsset.role)/\(fileName)"
        
        let finalURL = store.baseDirectory().appendingPathComponent(finalRelativePath)
        let folderURL = finalURL.deletingLastPathComponent()
        
        // Pastikan folder role ada
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        // Hapus file lama jika ada (menimpa)
        if FileManager.default.fileExists(atPath: finalURL.path) {
            try FileManager.default.removeItem(at: finalURL)
        }
        
        // Pindahkan dari temp ke final
        try FileManager.default.moveItem(at: tempURL, to: finalURL)
        
        // Rekam ke LocalAssetStore
        let localAsset = LocalAsset(
            id: cloudAsset.assetId,
            role: cloudAsset.role,
            name: cloudAsset.name,
            assetType: cloudAsset.mimeType,
            relativePath: finalRelativePath,
            checksum: hashString // simpan checksum aktual
        )
        
        try store.saveAsset(asset: localAsset)
        await RuntimeTimelineLogger.shared.auditLog(step: "Asset Saved", status: "SUCCESS", detail: "\(cloudAsset.assetId)")
    }
}
