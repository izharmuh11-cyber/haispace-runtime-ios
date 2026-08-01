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

// MARK: - Qualification Report

public struct QualificationReport: Sendable {
    public let items: [QualificationItem]
    public let generatedAt: Date
    public let runtimeVersion: String

    public var passCount: Int { items.filter { $0.status == .pass }.count }
    public var failCount: Int { items.filter { $0.status == .fail }.count }
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

// Removed FailureInjectionType
