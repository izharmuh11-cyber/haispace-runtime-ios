// QualificationDashboardView.swift
// HaispaceRuntime — App/Views/Operator
//
// Dashboard M-009 Runtime Qualification.
// Menampilkan Runtime Readiness Score, status tiap checklist item,
// dan menyediakan Failure Injection controls.
//
// HANYA AKTIF DI #if DEBUG
// Mengikuti ADR-003: View ini hanya merender QualificationEngine state,
// tidak melakukan kalkulasi apapun secara mandiri.

import SwiftUI

#if DEBUG

public struct QualificationDashboardView: View {

    @Environment(AppState.self) private var appState
    private let engine = QualificationEngine.shared

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                scoreHeader
                failureInjectionPanel
                ForEach(QualificationSection.allCases, id: \.self) { section in
                    sectionCard(section: section)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Runtime Qualification")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await engine.runAll(appState: appState)
                    }
                } label: {
                    Label(engine.isRunning ? "Running..." : "Jalankan Semua", systemImage: "play.fill")
                }
                .disabled(engine.isRunning)
            }
        }
    }

    // MARK: - Score Header

    private var scoreHeader: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(engine.scorePercent))")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundStyle(scoreColor)
                Text("%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor)
            }
            Text("Runtime Readiness Score")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if engine.isRunning, let id = engine.currentRunningId {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Menguji \(id)...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let report = engine.report {
                verdictBadge(report.verdict)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var scoreColor: Color {
        switch engine.scorePercent {
        case 90...100: return .green
        case 70..<90:  return .yellow
        default:       return .red
        }
    }

    @ViewBuilder
    private func verdictBadge(_ verdict: QualificationVerdict) -> some View {
        Text(verdict.rawValue)
            .font(.caption.bold())
            .foregroundStyle(verdict == .qualified ? .white : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                verdict == .qualified ? Color.green : Color.red,
                in: Capsule()
            )
    }

    // MARK: - Scenario Execution Panel

    private var failureInjectionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Scenario Execution", systemImage: "testtube.2")
                .font(.headline)
                .foregroundStyle(.purple)

            Text("Jalankan skenario khusus untuk menguji ketahanan runtime.")
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
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "play.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
            // Header
            HStack {
                Text(section.rawValue.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(passCount)/\(total)")
                    .font(.caption.bold())
                    .foregroundStyle(passCount == total ? .green : .orange)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Items
            ForEach(items) { item in
                qualificationRow(item: item)
                if item.id != items.last?.id { Divider().padding(.leading, 16) }
            }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private func qualificationRow(item: QualificationItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(item.status.icon)
                .font(.body)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.id)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    if engine.currentRunningId == item.id {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                Text(item.criteria)
                    .font(.subheadline)
                if let note = item.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let dur = item.durationMs {
                    Text(String(format: "%.1f ms", dur))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

#endif
