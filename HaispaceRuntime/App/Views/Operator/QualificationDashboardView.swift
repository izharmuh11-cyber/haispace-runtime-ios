// QualificationDashboardView.swift
// HaispaceRuntime — App/Views/Operator
//
// Dashboard M-009B Runtime Certification.
// Menampilkan 5 Stage Sertifikasi, Domain Readiness Score, Evidence Package,
// dan Scenario Execution controls.
//
// HANYA AKTIF DI #if DEBUG
// Mengikuti ADR-003: View ini hanya merender QualificationEngine state.

import SwiftUI

#if DEBUG

public struct QualificationDashboardView: View {

    @Environment(AppState.self) private var appState
    private let engine = QualificationEngine.shared
    @State private var showExportSuccess = false
    @State private var exportedPath: String? = nil

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                certificationHeader
                certificationStagePanel
                if let pkg = engine.evidencePackage {
                    domainScorePanel(pkg.domainScore)
                    exportPanel(pkg)
                }
                scenarioPanel
                ForEach(QualificationSection.allCases, id: \.self) { section in
                    sectionCard(section: section)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Sidang Sertifikasi M-009B")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await engine.runCertification(appState: appState)
                    }
                } label: {
                    Label(
                        engine.isRunning ? "Sidang Berlangsung..." : "Mulai Sidang",
                        systemImage: engine.isRunning ? "hourglass" : "checkmark.seal"
                    )
                }
                .disabled(engine.isRunning)
            }
        }
        .alert("Evidence Package Diekspor", isPresented: $showExportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportedPath ?? "Berhasil diekspor ke Documents/HaispaceQualification/")
        }
    }

    // MARK: - Certification Header

    private var certificationHeader: some View {
        VStack(spacing: 8) {
            if let pkg = engine.evidencePackage {
                // Final score after certification
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", pkg.domainScore.overall))
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundStyle(scoreColor(pkg.domainScore.overall))
                    Text("%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor(pkg.domainScore.overall))
                }
                Text("Overall Runtime Readiness")
                    .font(.subheadline).foregroundStyle(.secondary)

                if pkg.isEligibleForCertificate {
                    certBadge("✅ ELIGIBLE FOR CERTIFICATION", color: .green)
                } else {
                    certBadge("⏳ NOT YET ELIGIBLE", color: .orange)
                }
            } else {
                // Pre-certification
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(engine.scorePercent))")
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundStyle(scoreColor(engine.scorePercent))
                    Text("%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor(engine.scorePercent))
                }
                Text("Runtime Readiness Score")
                    .font(.subheadline).foregroundStyle(.secondary)

                if engine.isRunning, let stage = engine.currentStage {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text(stage.rawValue)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else if !engine.isRunning, engine.evidencePackage == nil {
                    Text("Tekan \"Mulai Sidang\" untuk memulai Sidang Sertifikasi M-009B")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Certification Stage Panel

    private var certificationStagePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Tahapan Sertifikasi", systemImage: "list.number")
                .font(.headline)
                .foregroundStyle(.primary)

            ForEach(CertificationStage.allCases) { stage in
                HStack(spacing: 12) {
                    Image(systemName: stage.icon)
                        .frame(width: 24)
                        .foregroundStyle(stageColor(stage))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stage.rawValue)
                            .font(.subheadline.bold())
                        Text(stage.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    stageStatusBadge(stage)
                }
                .padding(.vertical, 4)
                if stage != CertificationStage.allCases.last {
                    Divider().padding(.leading, 36)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func stageStatusBadge(_ stage: CertificationStage) -> some View {
        if engine.currentStage == stage && engine.isRunning {
            ProgressView().controlSize(.mini)
        } else if let status = engine.stageStatuses[stage] {
            Text(status.icon)
        } else {
            Text("⬜")
        }
    }

    private func stageColor(_ stage: CertificationStage) -> Color {
        guard let status = engine.stageStatuses[stage] else {
            return engine.currentStage == stage ? .blue : .secondary
        }
        switch status {
        case .pass:    return .green
        case .fail:    return .red
        case .running: return .blue
        default:       return .secondary
        }
    }

    // MARK: - Domain Score Panel (M-009B-03)

    private func domainScorePanel(_ score: RuntimeReadinessDomainScore) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Domain Readiness Score", systemImage: "chart.bar.fill")
                .font(.headline)

            domainRow("Boot",          value: score.boot)
            domainRow("Workflow",       value: score.workflow)
            domainRow("Hardware",       value: score.hardware)
            domainRow("Recovery",       value: score.recovery)
            domainRow("Observability",  value: score.observability)
            Divider()
            domainRow("Overall",        value: score.overall, isBold: true)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func domainRow(_ label: String, value: Double, isBold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(isBold ? .subheadline.bold() : .subheadline)
            Spacer()
            Text(String(format: "%.1f%%", value))
                .font(isBold ? .subheadline.bold() : .subheadline)
                .foregroundStyle(scoreColor(value))
        }
    }

    // MARK: - Export Panel (Resolution M-009B-01)

    private func exportPanel(_ pkg: EvidencePackage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Evidence Package", systemImage: "archivebox.fill")
                .font(.headline)
                .foregroundStyle(.indigo)

            Text("Evidence Package siap diekspor. File JSON dan Markdown Report akan disimpan ke Documents/HaispaceQualification/")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: "doc.badge.clock")
                Text("Timeline Events: \(pkg.timelineEventCount)")
                    .font(.caption)
            }
            HStack(spacing: 8) {
                Image(systemName: "folder.badge.questionmark")
                Text("Orphaned Sessions: \(pkg.auditTrailSessionCount)")
                    .font(.caption)
            }

            Button {
                do {
                    let url = try QualificationExporter.export(pkg)
                    exportedPath = url.path
                    showExportSuccess = true
                } catch {
                    exportedPath = "Export failed: \(error.localizedDescription)"
                    showExportSuccess = true
                }
            } label: {
                Label("Export Evidence Package", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Scenario Panel (Manual override)

    private var scenarioPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Manual Scenario Override", systemImage: "testtube.2")
                .font(.headline)
                .foregroundStyle(.purple)

            Text("Jalankan skenario secara manual di luar Sidang Sertifikasi (hanya untuk debugging).")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(QualificationScenario.allCases) { scenario in
                Button {
                    Task {
                        await ScenarioEngine.shared.run(scenario: scenario, appState: appState)
                    }
                } label: {
                    HStack {
                        Image(systemName: scenario == .restoreAll ? "arrow.counterclockwise" : "bolt.slash.fill")
                            .foregroundStyle(scenario == .restoreAll ? .green : .purple)
                        Text(scenario.rawValue)
                            .font(.subheadline).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "play.fill")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(.background, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Section Card

    private func sectionCard(section: QualificationSection) -> some View {
        let items = engine.items(for: section)
        let passCount = items.filter { $0.status == .pass }.count
        let total = items.count

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(section.rawValue.uppercased())
                    .font(.caption.bold()).foregroundStyle(.secondary)
                Spacer()
                Text("\(passCount)/\(total)")
                    .font(.caption.bold())
                    .foregroundStyle(passCount == total ? .green : .orange)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            Divider()
            ForEach(items) { item in
                qualificationRow(item: item)
                if item.id != items.last?.id { Divider().padding(.leading, 16) }
            }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private func qualificationRow(item: QualificationItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(item.status.icon).font(.body)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.id).font(.caption.bold()).foregroundStyle(.secondary)
                    if engine.currentRunningId == item.id { ProgressView().controlSize(.mini) }
                }
                Text(item.criteria).font(.subheadline)
                if let note = item.note {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }
                if let dur = item.durationMs {
                    Text(String(format: "%.1f ms", dur)).font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func scoreColor(_ value: Double) -> Color {
        switch value {
        case 95...100: return .green
        case 80..<95:  return .yellow
        default:       return .red
        }
    }

    private func certBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(color, in: Capsule())
    }
}

#endif
