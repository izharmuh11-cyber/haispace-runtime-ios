// RuntimeTimelineLogger.swift
// HaispaceRuntime — Core/Diagnostics

import Foundation
import Observation
import OSLog

public struct RuntimeTimelineEvent: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let type: String
    public let payload: String?
    
    public var displayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeStr = formatter.string(from: timestamp)
        if let payload = payload {
            return "[\(type)] \(timeStr) | \(payload)"
        }
        return "[\(type)] \(timeStr)"
    }
}

@Observable
@MainActor
public final class RuntimeTimelineLogger {
    public static let shared = RuntimeTimelineLogger()
    
    private let logger = Logger(subsystem: "id.haispaceproject.runtime", category: "Timeline")
    
    public private(set) var events: [RuntimeTimelineEvent] = []
    
    // M1 Audit: Session & Build Tracker
    public let sessionId: String
    
    // Helper untuk kompatibilitas dengan UI lama (BootstrapLoadingView)
    public var timeline: [String] {
        events.map { $0.displayString }
    }
    
    private init() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        self.sessionId = formatter.string(from: Date())
        
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "E9"
        
        logEvent("==============================")
        logEvent("SESSION STARTED", payload: self.sessionId)
        logEvent("BUILD INFO", payload: "v\(appVersion) (\(buildNumber))")
        logEvent("==============================")
    }
    
    public func logEvent(_ type: String, payload: String? = nil) {
        let event = RuntimeTimelineEvent(timestamp: Date(), type: type, payload: payload)
        events.append(event)
        
        // Print to console and OSLog
        print(event.displayString)
        logger.info("\(event.displayString)")
        
        // Simpan juga ke file log agar bisa diupload ke R2
        HaispaceLogger.info(event.displayString, category: "timeline")
    }
    
    // MARK: - M1 Audit Helper
    
    public func auditLog(step: String, status: String = "SUCCESS", detail: String? = nil) {
        let prefix = "[M1_AUDIT] [\(status.uppercased())] \(step)"
        logEvent(prefix, payload: detail)
    }
    
    public func exportLogs() -> String {
        return events.map { $0.displayString }.joined(separator: "\n")
    }
}
