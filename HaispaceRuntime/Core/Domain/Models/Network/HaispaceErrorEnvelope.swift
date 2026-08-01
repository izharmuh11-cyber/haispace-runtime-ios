import Foundation

/// Represents the standard error envelope returned by Haispace Cloud (NestJS Backend).
/// Ref: CLOUD_CONTRACT.md & ERROR_MODEL.md
public struct HaispaceErrorEnvelope: Codable, Error, LocalizedError {
    public let code: String
    public let category: String
    public let message: String
    public let retryable: Bool
    public let retryAfterSeconds: Int?
    public let correlationId: String?
    public let timestamp: String
    public let detail: [String: AnyCodable]?

    public var errorDescription: String? {
        return "[\(code)] \(message)"
    }
}

/// A wrapper to decode Cloud error response format: `{ "error": HaispaceErrorEnvelope }`
public struct CloudErrorResponse: Codable {
    public let error: HaispaceErrorEnvelope
}
