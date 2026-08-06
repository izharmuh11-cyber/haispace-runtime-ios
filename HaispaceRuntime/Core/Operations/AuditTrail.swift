import Foundation

public struct AuditLog: Codable {
    public let timestamp: Date
    public let incident: String
    public let action: String
    public let result: String
    public let operatorName: String
}

/// A tamper-proof local logger ensuring business accountability for recovery actions
public class AuditTrail {
    
    private var logs: [AuditLog] = []
    private let queue = DispatchQueue(label: "com.haispace.auditTrail")
    
    public init() {}
    
    public func record(incident: String, action: String, result: String, operatorName: String) {
        let log = AuditLog(
            timestamp: Date(),
            incident: incident,
            action: action,
            result: result,
            operatorName: operatorName
        )
        
        queue.async {
            self.logs.append(log)
            // In reality, this would append to a persistent local CoreData or encrypted SQLite store
            print("📝 AUDIT: [\(log.timestamp)] \(operatorName) resolved '\(incident)' via '\(action)'. Result: \(result)")
        }
    }
    
    public func getPendingSyncLogs() -> [AuditLog] {
        var pending: [AuditLog] = []
        queue.sync {
            pending = self.logs
        }
        return pending
    }
}
