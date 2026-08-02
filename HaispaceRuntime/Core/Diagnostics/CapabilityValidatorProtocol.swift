// CapabilityValidatorProtocol.swift
// HaispaceRuntime — Core/Diagnostics
//
// Platform Diagnostics Pattern — Chief GPT Review, 2026-08-02
//
// FILOSOFI:
//   Setiap capability di Haispace Platform memiliki satu validator.
//   Semua validator mengikuti kontrak yang sama.
//   PlatformDiagnosticsService mengumpulkan semuanya.
//
//   Sehingga operator cukup tekan:
//       "Run Platform Validation"
//   Lalu semua capability mengetes dirinya sendiri.
//
// POLA:
//   CapabilityValidatorProtocol
//       ↓
//   FrameEngineValidator     (M-012)
//   CameraValidator          (M-016)
//   PrinterValidator         (M-014)
//   CloudValidator           (M-015)

import Foundation

// MARK: - CapabilityValidatorProtocol

/// Kontrak standar untuk semua capability validator di Haispace Platform.
/// Setiap capability baru wajib memiliki implementasi protokol ini.
public protocol CapabilityValidatorProtocol: AnyObject, Sendable {
    
    /// Nama capability yang divalidasi (untuk tampilan di Mission Control)
    var capabilityName: String { get }
    
    /// Icon SF Symbol untuk ditampilkan di Diagnostics UI
    var capabilityIcon: String { get }
    
    /// Jalankan seluruh rangkaian check.
    /// Method ini harus idempotent — bisa dipanggil berkali-kali dengan hasil yang konsisten.
    func runValidation() async -> CapabilityValidationResult
}

// MARK: - CapabilityValidationResult

/// Hasil validasi satu capability.
public struct CapabilityValidationResult: Sendable, Codable, Identifiable {
    public let id: String
    public let capabilityName: String
    public let capabilityIcon: String
    public let checks: [ValidationCheck]
    public let totalDurationMs: Double
    public let validatedAt: Date
    public let milestone: String
    
    public var passedCount: Int  { checks.filter { $0.passed }.count }
    public var failedCount: Int  { checks.filter { $0.status == .failed }.count }
    public var warningCount: Int { checks.filter { $0.status == .warning }.count }
    public var allPassed: Bool   { failedCount == 0 }
    
    public var overallStatus: ValidationCheckStatus {
        if failedCount > 0 { return .failed }
        if warningCount > 0 { return .warning }
        return .passed
    }
    
    public var summaryLine: String {
        "\(capabilityName): \(passedCount)/\(checks.count) checks — \(String(format: "%.0f", totalDurationMs))ms — \(overallStatus.label)"
    }
    
    public init(
        capabilityName: String,
        capabilityIcon: String,
        checks: [ValidationCheck],
        totalDurationMs: Double,
        milestone: String,
        validatedAt: Date = Date()
    ) {
        self.id = UUID().uuidString
        self.capabilityName = capabilityName
        self.capabilityIcon = capabilityIcon
        self.checks = checks
        self.totalDurationMs = totalDurationMs
        self.milestone = milestone
        self.validatedAt = validatedAt
    }
}

// MARK: - ValidationCheckStatus

/// Status check yang bisa dipakai oleh semua validator.
public enum ValidationCheckStatus: String, Codable, Sendable {
    case pending = "pending"
    case passed  = "passed"
    case failed  = "failed"
    case warning = "warning"
    case skipped = "skipped"
    
    public var emoji: String {
        switch self {
        case .pending: return "⏳"
        case .passed:  return "✅"
        case .failed:  return "❌"
        case .warning: return "⚠️"
        case .skipped: return "⬛"
        }
    }
    
    public var label: String {
        switch self {
        case .pending: return "PENDING"
        case .passed:  return "PASS"
        case .failed:  return "FAIL"
        case .warning: return "WARN"
        case .skipped: return "SKIP"
        }
    }
}

// MARK: - ValidationCheck (Platform Standard)

/// Check item standar yang dipakai oleh semua validator.
public struct ValidationCheck: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let step: Int
    public private(set) var status: ValidationCheckStatus
    public private(set) var detail: String
    
    public var passed: Bool { status == .passed || status == .warning }
    
    public init(name: String, step: Int) {
        self.id = UUID().uuidString
        self.name = name
        self.step = step
        self.status = .pending
        self.detail = ""
    }
    
    public mutating func pass(detail: String) { self.status = .passed;  self.detail = detail }
    public mutating func fail(detail: String) { self.status = .failed;  self.detail = detail }
    public mutating func warn(detail: String) { self.status = .warning; self.detail = detail }
    public mutating func skip(detail: String) { self.status = .skipped; self.detail = detail }
}
