// DiagnosticsDashboardView.swift
// HaispaceRuntime — App/Views/Operator
//
// Platform Diagnostics UI — accessible dari OperatorDashboard.
//
// Chief GPT Vision:
//   Operator datang ke venue.
//   Tekan "Run Platform Validation".
//   Semua capability mengetes dirinya sendiri.
//   Kalau semua hijau — booth siap dipakai.

import SwiftUI

// MARK: - DiagnosticsDashboardView

struct DiagnosticsDashboardView: View {
    
    @StateObject private var diagnostics = PlatformDiagnosticsService()
    @State private var showDetailFor: CapabilityValidationResult?
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "#080C1A")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // ── Header ─────────────────────────────────────────────────
                header
                
                ScrollView {
                    VStack(spacing: 16) {
                        
                        // ── Platform Status Banner ──────────────────────────
                        if diagnostics.hasResults {
                            statusBanner
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                        }
                        
                        // ── Capability Cards ────────────────────────────────
                        VStack(spacing: 12) {
                            ForEach(diagnostics.results) { result in
                                CapabilityStatusCard(result: result)
                                    .onTapGesture { showDetailFor = result }
                            }
                            
                            // Placeholder cards jika belum dijalankan
                            if !diagnostics.hasResults {
                                emptyStateCards
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, diagnostics.hasResults ? 16 : 28)
                        
                        // ── Last Run Info ───────────────────────────────────
                        if let lastRun = diagnostics.lastRunAt {
                            Text("Terakhir dijalankan: \(lastRun.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                                .padding(.top, 8)
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
                
                // ── Run Button ──────────────────────────────────────────────
                runButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .padding(.top, 12)
            }
        }
        .sheet(item: $showDetailFor) { result in
            CapabilityDetailSheet(result: result)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Platform Diagnostics")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Haispace Runtime v1.0")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.purple)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .background(Color(hex: "#0D1228"))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(height: 1)
        }
    }
    
    // MARK: - Status Banner
    
    private var statusBanner: some View {
        let allPassed = diagnostics.allPassed
        return HStack(spacing: 12) {
            Image(systemName: allPassed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundStyle(allPassed ? .green : .orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(allPassed ? "Platform Siap" : "Ada Capability Bermasalah")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text(allPassed ? "Semua capability aktif dan terverifikasi" : "Periksa detail di bawah sebelum memulai acara")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(allPassed ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(allPassed ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Empty State Cards (belum dijalankan)
    
    private var emptyStateCards: some View {
        let placeholders: [(name: String, icon: String, milestone: String)] = [
            ("Camera", "camera", "M-010"),
            ("Frame Engine", "photo.stack", "M-012"),
            ("Printer", "printer", "M-014"),
            ("Cloud", "cloud", "M-015")
        ]
        return ForEach(placeholders, id: \.name) { item in
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 44, height: 44)
                    Image(systemName: item.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.3))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(item.milestone)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.3))
                }
                Spacer()
                
                Text("—")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.25))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Run Button
    
    private var runButton: some View {
        Button(action: { Task { await diagnostics.runAll() } }) {
            HStack(spacing: 10) {
                if diagnostics.isRunning {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.9)
                    Text("Menjalankan validasi...")
                } else {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 20))
                    Text(diagnostics.hasResults ? "Jalankan Ulang" : "Run Platform Validation")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                diagnostics.isRunning
                    ? Color.white.opacity(0.1)
                    : LinearGradient(
                        colors: [Color(hex: "#7C3AED"), Color(hex: "#5B21B6")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
        }
        .disabled(diagnostics.isRunning)
        .foregroundStyle(.white)
        .animation(.easeInOut(duration: 0.2), value: diagnostics.isRunning)
    }
}

// MARK: - CapabilityStatusCard

struct CapabilityStatusCard: View {
    let result: CapabilityValidationResult
    
    private var statusColor: Color {
        switch result.overallStatus {
        case .passed:  return .green
        case .failed:  return .red
        case .warning: return .orange
        default:       return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: result.capabilityIcon)
                    .font(.system(size: 18))
                    .foregroundStyle(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.capabilityName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(result.passedCount)/\(result.checks.count) checks — \(result.milestone)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
            
            // Status Badge
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                Text(result.overallStatus.label)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(statusColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor.opacity(0.12))
            .clipShape(Capsule())
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(statusColor.opacity(result.overallStatus == .passed ? 0.2 : 0.35), lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - CapabilityDetailSheet

struct CapabilityDetailSheet: View {
    let result: CapabilityValidationResult
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color(hex: "#080C1A").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: result.capabilityIcon)
                        .font(.system(size: 20))
                        .foregroundStyle(.purple)
                    Text(result.capabilityName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Tutup") { dismiss() }
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(Color(hex: "#0D1228"))
                
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(result.checks) { check in
                            CheckDetailRow(check: check)
                        }
                        
                        // Duration footer
                        HStack {
                            Text("Total durasi:")
                                .foregroundStyle(.white.opacity(0.5))
                            Spacer()
                            Text(String(format: "%.0fms", result.totalDurationMs))
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 16)
                }
            }
        }
    }
}

// MARK: - CheckDetailRow

struct CheckDetailRow: View {
    let check: ValidationCheck
    
    private var statusColor: Color {
        switch check.status {
        case .passed:  return .green
        case .failed:  return .red
        case .warning: return .orange
        case .skipped: return .gray
        default:       return .gray
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(check.status.emoji)
                .font(.system(size: 16))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 3) {
                Text("[\(check.step)] \(check.name)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                if !check.detail.isEmpty {
                    Text(check.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(statusColor.opacity(0.06))
                .padding(.horizontal, 12)
        )
    }
}


#Preview {
    DiagnosticsDashboardView()
}
