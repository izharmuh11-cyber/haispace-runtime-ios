import Foundation
import CoreImage

/// Represents the discrete lifecycle states of a customer transaction
public enum RenderJobState: String, Codable {
    case created = "CREATED"
    case captured = "CAPTURED"
    case rendering = "RENDERING"
    case readyToPrint = "READY_TO_PRINT"
    case printing = "PRINTING"
    case completed = "COMPLETED"
    case retryPending = "RETRY_PENDING"
}

/// A serialized task tracking the entire post-capture pipeline.
/// Designed for offline crash recovery.
public struct RenderJob: Codable, Identifiable {
    public let id: UUID
    public let sessionId: String
    public let assetVersion: Int
    
    public var status: RenderJobState
    public var lastUpdatedAt: Date
    public var errorMessage: String?
    
    public init(id: UUID = UUID(), sessionId: String, assetVersion: Int, status: RenderJobState = .created) {
        self.id = id
        self.sessionId = sessionId
        self.assetVersion = assetVersion
        self.status = status
        self.lastUpdatedAt = Date()
    }
    
    mutating func transition(to newState: RenderJobState, error: Error? = nil) {
        self.status = newState
        self.lastUpdatedAt = Date()
        if let err = error {
            self.errorMessage = err.localizedDescription
            self.status = .retryPending
        }
    }
}
