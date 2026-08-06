import Foundation

public enum RecoveryCommand: Codable {
    case retryPrintJob(jobId: UUID)
    case restartPrinterConnection
    case clearQueue
    case requestDiagnostics
    case lockBooth // Temporarily disables guest interactions
}

public struct CommandRequest: Codable {
    public let commandId: UUID
    public let command: RecoveryCommand
    public let issuedBy: String
    public let timestamp: Date
}
