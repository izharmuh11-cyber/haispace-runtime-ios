import Foundation

public struct CloudAssetDTO: Codable, Equatable {
    public let assetId: String
    public let role: String
    public let name: String
    public let mimeType: String
    public let downloadUrl: String?
    public let checksum: String?
    public let version: Int?
    
    // Backward compatibility properties
    public var id: String { assetId }
    public var assetType: String { mimeType }
    
    enum CodingKeys: String, CodingKey {
        case assetId, id
        case role
        case name
        case mimeType, assetType
        case downloadUrl
        case checksum
        case version
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Flexible key decoding: assetId or id
        if let aid = try container.decodeIfPresent(String.self, forKey: .assetId) {
            self.assetId = aid
        } else if let id = try container.decodeIfPresent(String.self, forKey: .id) {
            self.assetId = id
        } else {
            throw DecodingError.keyNotFound(CodingKeys.assetId, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing assetId or id"))
        }
        
        self.role = try container.decode(String.self, forKey: .role)
        self.name = try container.decode(String.self, forKey: .name)
        
        // Flexible key decoding: mimeType or assetType
        if let mt = try container.decodeIfPresent(String.self, forKey: .mimeType) {
            self.mimeType = mt
        } else if let at = try container.decodeIfPresent(String.self, forKey: .assetType) {
            self.mimeType = at
        } else {
            self.mimeType = "unknown"
        }
        
        self.downloadUrl = try container.decodeIfPresent(String.self, forKey: .downloadUrl)
        self.checksum = try container.decodeIfPresent(String.self, forKey: .checksum)
        self.version = try container.decodeIfPresent(Int.self, forKey: .version)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(assetId, forKey: .assetId)
        try container.encode(role, forKey: .role)
        try container.encode(name, forKey: .name)
        try container.encode(mimeType, forKey: .mimeType)
        try container.encodeIfPresent(downloadUrl, forKey: .downloadUrl)
        try container.encodeIfPresent(checksum, forKey: .checksum)
        try container.encodeIfPresent(version, forKey: .version)
    }
    
    // Main Initializer
    public init(assetId: String, role: String, name: String, mimeType: String, downloadUrl: String?, checksum: String?, version: Int? = nil) {
        self.assetId = assetId
        self.role = role
        self.name = name
        self.mimeType = mimeType
        self.downloadUrl = downloadUrl
        self.checksum = checksum
        self.version = version
    }
    
    // Backward-compatible Initializer
    public init(id: String, role: String, name: String, assetType: String, downloadUrl: String?, checksum: String?, version: Int? = nil) {
        self.assetId = id
        self.role = role
        self.name = name
        self.mimeType = assetType
        self.downloadUrl = downloadUrl
        self.checksum = checksum
        self.version = version
    }
}
