// QualificationSharedTypes.swift
// HaispaceRuntime — Core/Qualification
//
// Tipe data bersama untuk Qualification Engine.
// Merefleksikan seluruh section dari RUNTIME_ACCEPTANCE_PROTOCOL.md
//
// PENTING: Seluruh fitur Qualification hanya aktif saat #if DEBUG
// untuk mencegah operator lapangan tidak sengaja menjalankan Failure Injection.

import Foundation

// MARK: - Qualification Section

public enum QualificationSection: String, CaseIterable, Sendable {
    case boot          = "Boot"
    case session       = "Session"
    case recovery      = "Recovery"
    case observability = "Observability"
    case performance   = "Performance"
}

// MARK: - Certification Stage (Resolution M-009B-06)

public enum CertificationStage: String, CaseIterable, Sendable, Identifiable {
    public var id: String { rawValue }

    case bootstrap     = "Stage 1: Bootstrap Certification"
    case workflow      = "Stage 2: Workflow Certification"
    case recovery      = "Stage 3: Recovery Certification"
    case observability = "Stage 4: Observability Certification"
    case constitution  = "Stage 5: Constitution Certification"

    public var description: String {
        switch self {
        case .bootstrap:     return "Membuktikan Bootstrap Lifecycle"
        case .workflow:      return "Membuktikan Session Aggregate & Workflow Contract"
        case .recovery:      return "Membuktikan Workflow Resilience & Runtime Guarantees"
        case .observability: return "Membuktikan Observability Constitution"
        case .constitution:  return "Membuktikan Architecture Invariants dari Evidence"
        }
    }

    public var icon: String {
        switch self {
        case .bootstrap:     return "power"
        case .workflow:      return "arrow.triangle.2.circlepath"
        case .recovery:      return "bolt.shield"
        case .observability: return "eye"
        case .constitution:  return "checkmark.seal"
        }
    }
}

// MARK: - Item Status

public enum QualificationStatus: String, Sendable, Equatable {
    case pending  = "Pending"
    case pass     = "Pass"
    case partial  = "Partial"
    case fail     = "Fail"
    case running  = "Running"

    public var icon: String {
        switch self {
        case .pass:    return "✅"
        case .partial: return "🟡"
        case .fail:    return "❌"
        case .pending: return "⬜"
        case .running: return "⏳"
        }
    }

    public var color: String {
        switch self {
        case .pass:    return "green"
        case .partial: return "yellow"
        case .fail:    return "red"
        case .pending: return "gray"
        case .running: return "blue"
        }
    }
}

// MARK: - Qualification Item

public struct QualificationItem: Identifiable, Sendable {
    public let id: String         // e.g. "B-001"
    public let section: QualificationSection
    public let criteria: String
    public var status: QualificationStatus
    public var note: String?
    public var durationMs: Double?

    public init(
        id: String,
        section: QualificationSection,
        criteria: String,
        status: QualificationStatus = .pending,
        note: String? = nil
    ) {
        self.id = id
        self.section = section
        self.criteria = criteria
        self.status = status
        self.note = note
    }
}

// MARK: - Scenario Evidence Record (Resolution M-009B-02)

/// Bukti empiris dari satu skenario eksekusi ScenarioEngine.
/// Ini adalah atom terkecil dari EvidencePackage.
public struct ScenarioEvidenceRecord: Sendable {
    public let scenarioName: String
    public let constitutionRef: String         // e.g. "Capability Isolation"
    public let startedAt: Date
    public let recoveredAt: Date?
    public let recoveryDurationMs: Double?
    public let stateTransition: String         // e.g. ".available → .error → .available"
    public let workflowTransition: String?     // e.g. ".activeSession → .landing"
    public let zeroOrphanedSessions: Bool
    public let status: QualificationStatus
    public let notes: String?

    public init(
        scenarioName: String,
        constitutionRef: String,
        startedAt: Date,
        recoveredAt: Date? = nil,
        stateTransition: String,
        workflowTransition: String? = nil,
        zeroOrphanedSessions: Bool = true,
        status: QualificationStatus,
        notes: String? = nil
    ) {
        self.scenarioName = scenarioName
        self.constitutionRef = constitutionRef
        self.startedAt = startedAt
        self.recoveredAt = recoveredAt
        self.recoveryDurationMs = recoveredAt.map {
            $0.timeIntervalSince(startedAt) * 1000
        }
        self.stateTransition = stateTransition
        self.workflowTransition = workflowTransition
        self.zeroOrphanedSessions = zeroOrphanedSessions
        self.status = status
        self.notes = notes
    }
}

// MARK: - Runtime Readiness Domain Score (Resolution M-009B-03)

/// Multi-dimensional score — bukan satu angka statis.
public struct RuntimeReadinessDomainScore: Sendable {
    public let boot: Double
    public let workflow: Double
    public let hardware: Double
    public let recovery: Double
    public let observability: Double

    public var overall: Double {
        // Weighted average: workflow & session lebih kritis
        (boot * 0.20) + (workflow * 0.25) + (hardware * 0.20) +
        (recovery * 0.20) + (observability * 0.15)
    }

    public static let zero = RuntimeReadinessDomainScore(
        boot: 0, workflow: 0, hardware: 0, recovery: 0, observability: 0
    )
}

// MARK: - Evidence Package (Resolution M-009B-01)

/// Paket bukti resmi yang WAJIB ada sebelum Certificate dapat diterbitkan.
/// Certificate tanpa EvidencePackage adalah opini, bukan fakta.
public struct EvidencePackage: Sendable {
    public let generatedAt: Date
    public let runtimeVersion: String
    public let qualificationItems: [QualificationItem]
    public let scenarioEvidence: [ScenarioEvidenceRecord]
    public let domainScore: RuntimeReadinessDomainScore
    public let timelineEventCount: Int
    public let auditTrailSessionCount: Int
    public let healthSnapshotSummary: String

    public var isEligibleForCertificate: Bool {
        let bootPass = qualificationItems
            .filter { $0.section == .boot }
            .allSatisfy { $0.status == .pass }
        let sessionPass = qualificationItems
            .filter { $0.section == .session }
            .allSatisfy { $0.status == .pass }
        let scenarioPassed = scenarioEvidence
            .filter { $0.status == .pass }.count >= 3
        let noCriticalFail = qualificationItems
            .filter { $0.status == .fail }.isEmpty
        return bootPass && sessionPass && scenarioPassed &&
               noCriticalFail && domainScore.overall >= 95.0
    }
}

// MARK: - Qualification Report

public struct QualificationReport: Sendable {
    public let items: [QualificationItem]
    public let generatedAt: Date
    public let runtimeVersion: String

    public var passCount: Int    { items.filter { $0.status == .pass }.count }
    public var failCount: Int    { items.filter { $0.status == .fail }.count }
    public var partialCount: Int { items.filter { $0.status == .partial }.count }
    public var pendingCount: Int { items.filter { $0.status == .pending }.count }

    public var scorePercent: Double {
        guard !items.isEmpty else { return 0 }
        let score = items.reduce(0.0) { acc, item in
            switch item.status {
            case .pass:    return acc + 1.0
            case .partial: return acc + 0.5
            default:       return acc
            }
        }
        return (score / Double(items.count)) * 100
    }

    public func domainScore() -> RuntimeReadinessDomainScore {
        func pct(_ section: QualificationSection) -> Double {
            let sectionItems = items.filter { $0.section == section }
            guard !sectionItems.isEmpty else { return 100.0 }
            let passed  = sectionItems.filter { $0.status == .pass }.count
            let partial = sectionItems.filter { $0.status == .partial }.count
            return ((Double(passed) + Double(partial) * 0.5) / Double(sectionItems.count)) * 100
        }
        return RuntimeReadinessDomainScore(
            boot:          pct(.boot),
            workflow:      pct(.session),
            hardware:      pct(.performance),
            recovery:      pct(.recovery),
            observability: pct(.observability)
        )
    }

    public var verdict: QualificationVerdict {
        let bootItems     = items.filter { $0.section == .boot }
        let sessionItems  = items.filter { $0.section == .session }
        let recoveryItems = items.filter { $0.section == .recovery }
        let obsItems      = items.filter { $0.section == .observability }

        let bootPass     = bootItems.allSatisfy { $0.status == .pass }
        let sessionPass  = sessionItems.allSatisfy { $0.status == .pass }
        let recoveryPass = recoveryItems.filter { $0.status == .pass }.count >= 4
        let obsPass      = obsItems.allSatisfy { $0.status == .pass }

        if bootPass && sessionPass && recoveryPass && obsPass {
            return .qualified
        } else {
            return .notQualified
        }
    }
}

public enum QualificationVerdict: String, Sendable {
    case qualified    = "RUNTIME QUALIFIED"
    case notQualified = "TIDAK QUALIFIED"
}
