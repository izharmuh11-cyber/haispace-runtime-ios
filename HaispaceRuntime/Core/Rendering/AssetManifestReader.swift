import Foundation

public enum ManifestReaderError: Error {
    case fileNotFound
    case unreadableData
    case decodingFailed(Error)
    case invalidLayout
}

public class AssetManifestReader {
    
    public init() {}
    
    /// Parses the template.json file extracted from .hspasset
    public func parse(fileURL: URL) throws -> FrameProductManifest {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ManifestReaderError.fileNotFound
        }
        
        guard let data = try? Data(contentsOf: fileURL) else {
            throw ManifestReaderError.unreadableData
        }
        
        do {
            let decoder = JSONDecoder()
            let manifest = try decoder.decode(FrameProductManifest.self, from: data)
            
            if manifest.layouts.isEmpty {
                throw ManifestReaderError.invalidLayout
            }
            
            return manifest
        } catch {
            throw ManifestReaderError.decodingFailed(error)
        }
    }
}
