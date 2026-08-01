import Foundation

// MARK: - Session Archive DTO

public struct SessionArchiveDTO: Encodable {
    public let sessionId: String
    public let boothId: String
    public let eventId: String
    public let manifestVersion: String
    public let snapshotSchemaVersion: String
    public let architectureVersion: String
    public let snapshotVersion: Int
    public let packageId: String
    
    public let archiveStatus: String // "in_progress", "completed", "failed", "abandoned"
    public let startedAt: String
    public let completedAt: String?
    
    // Detailed Data
    public let captureData: [String: AnyCodable]?
    public let paymentData: [String: AnyCodable]?
    public let metadata: [String: AnyCodable]?
}

// MARK: - Domain Events DTO

public struct DomainEventRecordDTO: Encodable {
    public let eventId: String
    public let sessionId: String?
    public let boothId: String
    public let correlationId: String?
    public let eventType: String
    public let payload: [String: AnyCodable]
    public let occurredAt: String
}

public struct DomainEventsBatchRequest: Encodable {
    public let events: [DomainEventRecordDTO]
    public init(events: [DomainEventRecordDTO]) { self.events = events }
}

public struct BatchIngestResponse: Decodable {
    public let acceptedCount: Int
    public let duplicateCount: Int
}

// MARK: - Audit Events DTO

public struct AuditRecordDTO: Encodable {
    public let auditId: String
    public let organizationId: String
    public let boothId: String
    public let category: String
    public let action: String
    public let outcome: String
    public let details: [String: AnyCodable]?
    public let occurredAt: String
}

public struct AuditEventsBatchRequest: Encodable {
    public let events: [AuditRecordDTO]
    public init(events: [AuditRecordDTO]) { self.events = events }
}
