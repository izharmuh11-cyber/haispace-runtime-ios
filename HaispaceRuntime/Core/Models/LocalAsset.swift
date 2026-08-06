import Foundation

public struct LocalAsset: Codable, Equatable {
    public let id: String
    public let role: String
    public let name: String
    public let assetType: String
    public let relativePath: String
    public let checksum: String?
    
    public init(id: String, role: String, name: String, assetType: String, relativePath: String, checksum: String?) {
        self.id = id
        self.role = role
        self.name = name
        self.assetType = assetType
        self.relativePath = relativePath
        self.checksum = checksum
    }
    
    /// Mendapatkan URL absolut dari asset ini di disk
    public func fileURL(baseDirectory: URL) -> URL {
        return baseDirectory.appendingPathComponent(relativePath)
    }
}
