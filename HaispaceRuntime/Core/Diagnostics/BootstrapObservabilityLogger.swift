// BootstrapObservabilityLogger.swift
// HaispaceRuntime — Core/Diagnostics

import Foundation
import OSLog

public final class BootstrapObservabilityLogger: @unchecked Sendable {
    public static let shared = BootstrapObservabilityLogger()
    
    private let logger = Logger(subsystem: "id.haispaceproject.runtime", category: "Bootstrap")
    
    // Simpan timeline in-memory jika ingin ditampilkan di UI nantinya
    private(set) var timeline: [String] = []
    
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
