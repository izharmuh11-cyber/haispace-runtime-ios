// QualificationExporter.swift
// HaispaceRuntime — Core/Qualification
//
// Mengubah EvidencePackage menjadi dua artefak persisten:
//   1. qualification_evidence_[timestamp].json  — raw data untuk audit mesin
//   2. qualification_report_[timestamp].md      — narasi yang bisa dibaca manusia
//
// HANYA AKTIF DI #if DEBUG

import Foundation
import OSLog

#if DEBUG

public enum QualificationExporter {

    private static let logger = Logger(
        subsystem: "id.haispaceproject.runtime",
        category: "QualificationExporter"
    )

    // MARK: - Public Entry Point

    /// Mengekspor EvidencePackage ke Documents directory.
    /// Returns URL folder hasil ekspor.
    @discardableResult
    public static func export(_ package: EvidencePackage) throws -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        let timestamp = formatter.string(from: package.generatedAt)
            .replacingOccurrences(of: ":", with: "-")

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = docs.appendingPathComponent("HaispaceQualification/\(timestamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        // 1. JSON Evidence
        let jsonURL = folder.appendingPathComponent("qualification_evidence.json")
        let jsonData = try buildJSON(package)
        try jsonData.write(to: jsonURL)

        // 2. Markdown Report
        let mdURL = folder.appendingPathComponent("qualification_report.md")
        let mdContent = buildMarkdown(package)
        try mdContent.data(using: .utf8)?.write(to: mdURL)

        logger.info("[QualificationExporter] Evidence Package exported to: \(folder.path)")
        return folder
    }

    // MARK: - JSON Builder

    private static func buildJSON(_ package: EvidencePackage) throws -> Data {
        var dict: [String: Any] = [
            "generatedAt": ISO8601DateFormatter().string(from: package.generatedAt),
            "runtimeVersion": package.runtimeVersion,
            "timelineEventCount": package.timelineEventCount,
            "auditTrailSessionCount": package.auditTrailSessionCount,
            "healthSnapshotSummary": package.healthSnapshotSummary,
            "eligibleForCertificate": package.isEligibleForCertificate,
            "domainScore": [
                "boot": package.domainScore.boot,
                "workflow": package.domainScore.workflow,
                "hardware": package.domainScore.hardware,
                "recovery": package.domainScore.recovery,
                "observability": package.domainScore.observability,
                "overall": package.domainScore.overall
            ],
            "qualificationItems": package.qualificationItems.map { item in
                [
                    "id": item.id,
                    "section": item.section.rawValue,
                    "criteria": item.criteria,
                    "status": item.status.rawValue,
                    "note": item.note ?? "",
                    "durationMs": item.durationMs ?? 0
                ] as [String: Any]
            },
            "scenarioEvidence": package.scenarioEvidence.map { rec in
                [
                    "scenarioName": rec.scenarioName,
                    "constitutionRef": rec.constitutionRef,
                    "startedAt": ISO8601DateFormatter().string(from: rec.startedAt),
                    "recoveryDurationMs": rec.recoveryDurationMs ?? -1,
                    "stateTransition": rec.stateTransition,
                    "workflowTransition": rec.workflowTransition ?? "N/A",
                    "zeroOrphanedSessions": rec.zeroOrphanedSessions,
                    "status": rec.status.rawValue,
                    "notes": rec.notes ?? ""
                ] as [String: Any]
            }
        ]
        return try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: - Markdown Builder

    private static func buildMarkdown(_ package: EvidencePackage) -> String {
        let df = DateFormatter()
        df.dateStyle = .long
        df.timeStyle = .medium
        let dateStr = df.string(from: package.generatedAt)
        let verdict = package.isEligibleForCertificate ? "✅ ELIGIBLE FOR CERTIFICATION" : "❌ NOT ELIGIBLE"

        var md = """
        # HAISPACE RUNTIME QUALIFICATION REPORT

        | Field                  | Value                          |
        |------------------------|-------------------------------|
        | Runtime Version        | \(package.runtimeVersion)      |
        | Qualification Date     | \(dateStr)                     |
        | Timeline Events        | \(package.timelineEventCount)  |
        | Audit Trail Sessions   | \(package.auditTrailSessionCount) |
        | Certification Verdict  | \(verdict)                     |

        ---

        ## Domain Readiness Score (Resolution M-009B-03)

        | Domain        | Score   |
        |---------------|---------|
        | Boot          | \(String(format: "%.1f", package.domainScore.boot))%     |
        | Workflow      | \(String(format: "%.1f", package.domainScore.workflow))%  |
        | Hardware      | \(String(format: "%.1f", package.domainScore.hardware))%  |
        | Recovery      | \(String(format: "%.1f", package.domainScore.recovery))%  |
        | Observability | \(String(format: "%.1f", package.domainScore.observability))% |
        | **Overall**   | **\(String(format: "%.1f", package.domainScore.overall))%** |

        ---

        ## Qualification Items

        | ID     | Section       | Criteria | Status |
        |--------|---------------|----------|--------|
        """

        for item in package.qualificationItems {
            let note = item.note.map { " (\($0))" } ?? ""
            md += "\n| \(item.id) | \(item.section.rawValue) | \(item.criteria)\(note) | \(item.status.icon) \(item.status.rawValue) |"
        }

        md += """

        ---

        ## Scenario Evidence (Resolution M-009B-02)

        """

        for rec in package.scenarioEvidence {
            md += """

            ### \(rec.status.icon) \(rec.scenarioName)
            - **Constitution Ref:** \(rec.constitutionRef)
            - **State Transition:** \(rec.stateTransition)
            - **Recovery Duration:** \(rec.recoveryDurationMs.map { String(format: "%.0f ms", $0) } ?? "N/A")
            - **Zero Orphaned Sessions:** \(rec.zeroOrphanedSessions ? "Yes" : "No")
            - **Status:** \(rec.status.rawValue)

            """
        }

        md += """

        ---

        ## Health Snapshot Summary

        \(package.healthSnapshotSummary)

        ---

        *Generated by QualificationExporter — Haispace Runtime \(package.runtimeVersion)*
        """

        return md
    }
}

#endif
