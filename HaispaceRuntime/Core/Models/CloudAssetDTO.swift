import Foundation

public struct CloudAssetDTO: Codable, Equatable {
    public let assetId: String
    public let role: String
    public let name: String
    public let mimeType: String
    public let downloadUrl: String?
    public let checksum: String?
    public let version: Int?
    
    // We ignore metadata for now unless we need specific layout coordinates
    
    public init(assetId: String, role: String, name: String, mimeType: String, downloadUrl: String?, checksum: String?, version: Int?) {
        self.assetId = assetId
        self.role = role
        self.name = name
        self.mimeType = mimeType
        self.downloadUrl = downloadUrl
        self.checksum = checksum
        self.version = version
    }
}
