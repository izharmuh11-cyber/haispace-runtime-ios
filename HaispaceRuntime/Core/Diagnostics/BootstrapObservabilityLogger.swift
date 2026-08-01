// BootstrapObservabilityLogger.swift
// HaispaceRuntime — Core/Diagnostics

import Foundation
import Observation
import OSLog

@Observable
@MainActor
public final class BootstrapObservabilityLogger {
    public static let shared = BootstrapObservabilityLogger()
    
    private let logger = Logger(subsystem: "id.haispaceproject.runtime", category: "Bootstrap")
    
    // Simpan timeline in-memory agar bisa ditampilkan di UI
    public private(set) var timeline: [String] = []
    
    private init() {}
    
    public func logEvent(_ event: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        
        let message = "[BOOTSTRAP] \(timestamp) | \(event)"
        timeline.append(message)
        
        // Print to console and OSLog
        print(message)
        logger.info("\(message)")
    }
}
