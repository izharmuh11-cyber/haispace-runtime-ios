// SessionRecoveryEngine.swift
// HaispaceRuntime — Core/Recovery
//
// Engine pemulihan sesi terputus (Orphaned Sessions) pasca crash/booting ulang.
// Mengisolasi logika deteksi audit trail dan penentuan alur recovery (RG-001 & RG-002).
//
// Ref: ADR-016, ADR-017, ADR-018

import Foundation

public actor SessionRecoveryEngine {
    
    // MARK: - Initializer
    public init() {}
    
    // MARK: - Recovery Operations
    
    /// Memindai semua audit log lokal untuk mendeteksi orphaned sessions.
    public func scanOrphanedSessions() -> [OrphanedSessionDecision] {
        return OrphanedSessionDetector.detect()
    }
    
    /// Menganalisis satu audit record dan menghasilkan rekomendasi pemulihan.
    public func analyzeRecord(_ record: AuditTrailRecord) -> OrphanedSessionDecision {
        return OrphanedSessionDetector.analyze(record: record)
    }
}
