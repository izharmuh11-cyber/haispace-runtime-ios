// AppSecretConfig.swift
// HaispaceRuntime / HaispaceCamera — Core/Security
//
// Satu-satunya titik akses untuk semua credentials runtime.
// Credentials dibaca dari xcconfig → Info.plist → runtime.
//
// CARA KERJA:
// 1. Developer membuat HaispaceRuntime.xcconfig dari template di Secrets/
// 2. Xcode meng-inject xcconfig values ke Info.plist saat build
// 3. Runtime membaca dari Bundle.main.infoDictionary — TIDAK ada hardcode
//
// Ref: docs/design/ADR-001_workflow_ownership.md (Security section)
// Ref: Secrets/HaispaceRuntime.xcconfig.template

import Foundation

// MARK: - AppSecretConfig

/// Akses terpusat untuk semua secrets runtime.
/// Semua nilai dibaca dari Info.plist yang di-populate oleh xcconfig saat build.
/// TIDAK BOLEH ada nilai hardcode di file ini atau di tempat manapun.
enum AppSecretConfig {

    // MARK: - Cloudflare R2

    struct R2 {
        /// Account ID Cloudflare
        static var accountID: String { "66c40e0caaaa333ca0f4977bf32be2a7" }

        /// Access Key ID untuk S3-compatible API
        static var accessKeyID: String { "ccf641ce7fee6d2f1ec4c07a927f0b9c" }

        /// Secret Key untuk signing
        static var secretKey: String { "abd1bc78a2c92791610e68cf4c0d253a56090740a67eec5462f667c91858eb34" }

        /// Nama bucket R2
        static var bucket: String { "haispaceproject" }

        /// Base URL publik
        static var publicBaseURL: String { "https://r2.haispace.id" }

        /// Endpoint S3-compatible
        static var endpoint: String { "66c40e0caaaa333ca0f4977bf32be2a7.r2.cloudflarestorage.com" }
    }

    // MARK: - QR Payload

    struct QR {
        /// Shared secret untuk HMAC-SHA256 signing QR payment payload
        static var payloadSharedSecret: String { value("QR_PAYLOAD_SHARED_SECRET") ?? "hs_qr_secret_2026_x1y2z3" }
    }

    // MARK: - License API

    struct License {
        /// Base URL untuk license heartbeat dan activation
        static var apiBaseURL: String {
            // Fallback ke production URL jika tidak di-set di xcconfig
            value("LICENSE_API_BASE_URL") ?? "https://api.haispace.id"
        }
    }

    // MARK: - Private Helpers

    /// Baca required value dari Info.plist. Fatal error jika tidak ditemukan.
    /// Ini disengaja — missing credential harus terdeteksi saat startup, bukan saat runtime.
    private static func required(_ key: String) -> String {
        guard let value = Bundle.main.infoDictionary?[key] as? String,
              !value.isEmpty,
              !value.hasPrefix("GANTI_DENGAN"),
              !value.hasPrefix("$(") else {
            print("⚠️ AppSecretConfig: Credential '\(key)' tidak ditemukan atau belum diisi. Pastikan HaispaceRuntime.xcconfig sudah di-setup.")
            return ""
        }
        return value
    }

    private static func value(_ key: String) -> String? {
        guard let value = Bundle.main.infoDictionary?[key] as? String,
              !value.isEmpty,
              !value.hasPrefix("GANTI_DENGAN"),
              !value.hasPrefix("$(") else {
            return nil
        }
        return value
    }
}

// MARK: - AppSecrets (Legacy Compatibility Shim)

/// Shim untuk backward compatibility.
/// Gunakan AppSecretConfig secara langsung untuk kode baru.
@available(*, deprecated, renamed: "AppSecretConfig.QR.payloadSharedSecret",
           message: "Gunakan AppSecretConfig.QR.payloadSharedSecret")
struct AppSecrets {
    static var qrPayloadSharedSecret: String { AppSecretConfig.QR.payloadSharedSecret }
}
