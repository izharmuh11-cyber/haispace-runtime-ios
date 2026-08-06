import Foundation

public struct CloudAssetDTO: Codable, Equatable {
    public let id: String
    public let role: String
    public let name: String
    public let assetType: String
    public let downloadUrl: String?
    public let checksum: String?
    
    // We ignore metadata for now unless we need specific layout coordinates
    
    public init(id: String, role: String, name: String, assetType: String, downloadUrl: String?, checksum: String?) {
        self.id = id
        self.role = role
        self.name = name
        self.assetType = assetType
        self.downloadUrl = downloadUrl
        self.checksum = checksum
    }
}
