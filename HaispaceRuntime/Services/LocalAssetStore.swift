import Foundation

public protocol LocalAssetStoreProtocol {
    func getAsset(id: String) -> LocalAsset?
    func getAllAssets() -> [LocalAsset]
    func saveAsset(asset: LocalAsset) throws
    func deleteAsset(id: String) throws
    func baseDirectory() -> URL
}

public class LocalAssetStore: LocalAssetStoreProtocol {
    private let userDefaultsKey = "id.haispaceproject.runtime.assets_registry"
    private let fileManager = FileManager.default
    private let defaults = UserDefaults.standard
    
    private var registry: [String: LocalAsset] = [:]
    
    public init() {
        loadRegistry()
    }
    
    public func baseDirectory() -> URL {
        // Menggunakan Document Directory agar persisten dan offline-ready
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Assets", isDirectory: true)
    }
    
    private func ensureBaseDirectoryExists() throws {
        let url = baseDirectory()
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    private func loadRegistry() {
        guard let data = defaults.data(forKey: userDefaultsKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([String: LocalAsset].self, from: data)
            self.registry = decoded
        } catch {
            print("Failed to decode asset registry: \(error)")
        }
    }
    
    private func saveRegistry() {
        do {
            let encoded = try JSONEncoder().encode(registry)
            defaults.set(encoded, forKey: userDefaultsKey)
        } catch {
            print("Failed to encode asset registry: \(error)")
        }
    }
    
    public func getAsset(id: String) -> LocalAsset? {
        return registry[id]
    }
    
    public func getAllAssets() -> [LocalAsset] {
        return Array(registry.values)
    }
    
    public func saveAsset(asset: LocalAsset) throws {
        try ensureBaseDirectoryExists()
        registry[asset.id] = asset
        saveRegistry()
    }
    
    public func deleteAsset(id: String) throws {
        guard let asset = registry[id] else { return }
        let fileUrl = asset.fileURL(baseDirectory: baseDirectory())
        if fileManager.fileExists(atPath: fileUrl.path) {
            try fileManager.removeItem(at: fileUrl)
        }
        registry.removeValue(forKey: id)
        saveRegistry()
    }
}
