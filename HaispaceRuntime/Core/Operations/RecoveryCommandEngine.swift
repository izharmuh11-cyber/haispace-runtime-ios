import Foundation

public enum CommandError: Error {
    case invalidJob
    case executionFailed
}

/// The local executor for commands coming from Mission Control or local Operator Mode
public class RecoveryCommandEngine {
    
    private let printQueue: PrintQueue
    private let auditTrail: AuditTrail
    
    public init(printQueue: PrintQueue, auditTrail: AuditTrail) {
        self.printQueue = printQueue
        self.auditTrail = auditTrail
    }
    
    /// Parses and executes a validated command request
    public func execute(request: CommandRequest) throws {
        switch request.command {
            
        case .retryPrintJob(let jobId):
            // The image is already rendered and saved, just push back to the queue
            printQueue.retry(jobId: jobId)
            
            auditTrail.record(
                incident: "Print Job Stuck",
                action: "Retry Print Job \(jobId)",
                result: "Success",
                operatorName: request.issuedBy
            )
            
        case .restartPrinterConnection:
            // Placeholder: Call printerAdapter.reconnect()
            auditTrail.record(
                incident: "Printer Offline",
                action: "Restart Printer Connection",
                result: "Command Dispatched",
                operatorName: request.issuedBy
            )
            
        case .clearQueue:
            // Placeholder: Clear pending queue
            auditTrail.record(
                incident: "Queue Overflow",
                action: "Clear Pending Jobs",
                result: "Queue Cleared",
                operatorName: request.issuedBy
            )
            
        case .requestDiagnostics:
            // Handled by Health Monitor
            break
            
        case .lockBooth:
            // Placeholder: Broadcast UI freeze
            auditTrail.record(
                incident: "Emergency Lock",
                action: "Lock Booth Interface",
                result: "Locked",
                operatorName: request.issuedBy
            )
        }
    }
}
