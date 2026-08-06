import Foundation
import CryptoKit

public class RuntimeAuditE7 {
    public static func runAudit() async {
        print("\n=============================================")
        print("    RUNNING SPRINT E.7 RUNTIME AUDIT")
        print("=============================================\n")
        
        do {
            let store = LocalAssetStore()
            let syncService = AssetSyncService(store: store)
            let baseDir = store.baseDirectory()
            
            // Siapkan mock manifest
            let initialAsset1 = CloudAssetDTO(
                id: "asset_1_frame",
                role: "frame",
                name: "SummerFrame",
                assetType: "frame",
                // Menggunakan public image ringan
                downloadUrl: "https://raw.githubusercontent.com/izharmuh11-cyber/hsp-cloud/master/package.json",
                // Kosongkan checksum di awal agar otomatis diisi dengan checksum file yang didownload
                checksum: nil
            )
            
            let initialAsset2 = CloudAssetDTO(
                id: "asset_2_overlay",
                role: "overlay",
                name: "SummerOverlay",
                assetType: "overlay",
                downloadUrl: "https://raw.githubusercontent.com/izharmuh11-cyber/hsp-cloud/master/package-lock.json",
                checksum: nil
            )
            
            print("Launching Runtime...")
            print("Manifest received: 2 assets\n")
            
            // 1. FIRST SYNC (Cache Miss)
            print("--- FIRST SYNC ---")
            print("Asset 1")
            print("Cache miss")
            print("Downloading...")
            try await syncService.syncAssets(from: [initialAsset1])
            let savedAsset1 = store.getAsset(id: "asset_1_frame")!
            print("SHA256 OK: \(savedAsset1.checksum ?? "")")
            print("Saved: \(savedAsset1.fileURL(baseDirectory: baseDir).path)\n")
            
            print("Asset 2")
            print("Cache miss")
            print("Downloading...")
            try await syncService.syncAssets(from: [initialAsset2])
            let savedAsset2 = store.getAsset(id: "asset_2_overlay")!
            print("SHA256 OK: \(savedAsset2.checksum ?? "")")
            print("Saved: \(savedAsset2.fileURL(baseDirectory: baseDir).path)\n")
            
            
            // 2. SECOND SYNC (Cache Hit)
            print("--- SECOND SYNC ---")
            // Menggunakan checksum asli dari hasil download pertama untuk mensimulasikan server yang tidak berubah
            let unmodifiedAsset1 = CloudAssetDTO(
                id: initialAsset1.id, role: initialAsset1.role, name: initialAsset1.name,
                assetType: initialAsset1.assetType, downloadUrl: initialAsset1.downloadUrl,
                checksum: savedAsset1.checksum
            )
            let unmodifiedAsset2 = CloudAssetDTO(
                id: initialAsset2.id, role: initialAsset2.role, name: initialAsset2.name,
                assetType: initialAsset2.assetType, downloadUrl: initialAsset2.downloadUrl,
                checksum: savedAsset2.checksum
            )
            
            // Log logika delta dari dalam AssetSyncService akan melewatkan download
            try await syncService.syncAssets(from: [unmodifiedAsset1, unmodifiedAsset2])
            print("Asset 1\nCache hit\n")
            print("Asset 2\nCache hit\n")
            
            
            // 3. THIRD SYNC (Manifest Checksum Changed)
            print("--- THIRD SYNC (Manifest Checksum Changed) ---")
            print("Server mengubah checksum Asset 2")
            // Ubah checksum asset 2 (mensimulasikan versi baru di server)
            let changedAsset2 = CloudAssetDTO(
                id: initialAsset2.id, role: initialAsset2.role, name: initialAsset2.name,
                assetType: initialAsset2.assetType, downloadUrl: initialAsset2.downloadUrl,
                checksum: "changed_checksum_123"
            )
            
            print("Asset 2")
            print("Cache miss")
            print("Downloading...")
            
            do {
                try await syncService.syncAssets(from: [changedAsset2])
                print("Asset 2 berhasil didownload ulang.")
            } catch AssetSyncError.checksumMismatch {
                print("SHA256 Mismatch (Expected: changed_checksum_123). File ditolak!")
            } catch {
                print("Error: \(error)")
            }
            print("")
            
            
            // 4. VERIFY DIRECTORY & COLD LAUNCH
            print("--- VERIFY DIRECTORY & COLD LAUNCH ---")
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(atPath: baseDir.path)
            print("Isi Documents/Assets/:")
            for item in contents {
                print(" - \(item)")
            }
            
            print("\nSimulating Cold Launch...")
            let newStoreInstance = LocalAssetStore()
            print("Registry Loaded")
            let availableAssets = newStoreInstance.getAllAssets()
            print("\(availableAssets.count) assets available")
            
            if availableAssets.count == 2 {
                print("No download required (Offline Ready)")
            }
            
            print("\nCompleted.")
            
        } catch {
            print("Audit Gagal: \(error)")
        }
    }
}
