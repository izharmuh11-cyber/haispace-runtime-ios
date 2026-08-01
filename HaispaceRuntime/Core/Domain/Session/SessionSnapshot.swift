// SessionSnapshot.swift
// HaispaceRuntime — Core/Domain/Session
//
// Kontrak penyimpanan yang stabil untuk HaispaceSession.
//
// PRINSIP (Ref: GPT Architecture Decision — Q10):
//   SessionSnapshot adalah kontrak penyimpanan, bukan cerminan class internal.
//   Perubahan implementasi enum di Swift tidak boleh merusak data recovery.
//   Semua field menggunakan tipe primitif yang stabil (String, Int, Date, Bool).
//
// ATURAN:
//   - Tidak ada tipe Swift-spesifik di sini (bukan enum langsung, bukan struct internal)
//   - Semua state dikodekan sebagai primitif + workflowStageId (String)
//   - Versi snapshot memungkinkan forward migration
//
// Ref: haispace-platform/architecture/ARP-004 — Q10 answer

import Foundation

// MARK: - SessionSnapshot

/// Value Object yang stabil untuk persistence Session ke disk.
/// Dibuat via HaispaceSession.snapshot() — hanya Session yang boleh membuat ini.
public struct SessionSnapshot: Codable, Sendable {

    // MARK: Schema
    /// Versi schema snapshot — berbeda dari Runtime Version dan Manifest Version.
    /// Diincrement setiap kali struktur SessionSnapshot berubah secara breaking.
    /// Digunakan oleh SessionRepository untuk memutuskan apakah perlu migration.
    public let snapshotSchemaVersion: Int  // Saat ini: 1

    // MARK: Identity
    public let sessionId: String
    public let boothId: String
    public let eventId: String
    public let packageId: String
    public let packageVersion: Int
    public let manifestVersion: Int
    public let startedAt: Date
    public let guestName: String
    public let guestPhone: String?
    public let guestQueueNumber: Int

    // MARK: Workflow State (stable string, not Swift enum)
    public let workflowStageId: String       // WorkflowStage.rawValue
    public let lifecycleStatus: String       // SessionLifecycleStatus.codableRepresentation

    // MARK: Capture State
    public let captureIds: [String]          // Ordered list of CaptureRecord IDs
    public let captureFilePaths: [String: String]  // CaptureID → file path
    public let selectedCaptureIds: [String]
    public let selectedFrameId: String?
    public let selectedFilterId: String?

    // MARK: Payment State
    public let paymentCommitment: PaymentCommitment?

    // MARK: Delivery State
    public let deliveryState: SessionDeliveryState

    // MARK: Output
    public let outputReference: String?      // Path ke file komposit final

    // MARK: Timer
    public let remainingSeconds: Int

    // MARK: Completion
    public let completedAt: Date?
    public let abortedAt: Date?
    public let abortReason: String?

    // MARK: Snapshot metadata
    public let snapshotAt: Date              // Kapan snapshot ini dibuat

    // MARK: - Convenience Queries

    /// Apakah snapshot ini merepresentasikan session yang punya komitmen finansial?
    public var hasFinancialCommitment: Bool {
        paymentCommitment?.isWorkflowAllowed ?? false
    }

    /// Apakah session ini perlu di-restore ke delivery?
    public var requiresDeliveryRestore: Bool {
        hasFinancialCommitment && outputReference != nil && !deliveryState.isAllDelivered
    }

    /// Apakah session ini aman untuk dihapus?
    public var isSafeToArchive: Bool {
        lifecycleStatus == "completed" || lifecycleStatus == "aborted"
    }
}

// MARK: - SessionSnapshot + Migration

extension SessionSnapshot {

    /// Migrate snapshot dari versi lama ke versi terbaru.
    /// Dipanggil oleh SessionRepository saat load dari disk.
    public func migrated() -> SessionSnapshot {
        // Version 1 adalah versi pertama — tidak ada migration yang diperlukan.
        // Saat version 2 tersedia, logic migration ditambahkan di sini.
        return self
    }
}


// MARK: - SessionSnapshotStore

/// Simpan dan load SessionSnapshot ke/dari disk secara atomik.
public enum SessionSnapshotStore {

    private static let snapshotDir: URL = {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("session_snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Write (Atomic)

    /// Simpan snapshot secara atomik (tmp → rename).
    /// Thread-safe: tulis ke file tmp dulu, lalu atomic rename ke path final.
    public static func save(_ snapshot: SessionSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }

        let finalURL = snapshotURL(for: snapshot.sessionId)
        let tmpURL = finalURL.appendingPathExtension("tmp")

        do {
            try data.write(to: tmpURL, options: .atomic)
            // Atomic rename — jika crash di sini, tmp file tidak dibaca
            _ = try FileManager.default.replaceItemAt(finalURL, withItemAt: tmpURL)
        } catch {
            // Fallback: direct write
            try? data.write(to: finalURL, options: .atomic)
        }
    }

    // MARK: - Read

    public static func load(sessionId: String) -> SessionSnapshot? {
        let url = snapshotURL(for: sessionId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(SessionSnapshot.self, from: data)
    }

    // MARK: - Delete (setelah session complete)

    public static func delete(sessionId: String) {
        let url = snapshotURL(for: sessionId)
        try? FileManager.default.removeItem(at: url)
        // Juga hapus tmp jika ada
        try? FileManager.default.removeItem(at: url.appendingPathExtension("tmp"))
    }

    // MARK: - Find All Orphans

    /// Semua snapshot yang masih ada = sesi yang belum selesai (orphaned jika app direstart)
    public static func allOrphanedSnapshots() -> [SessionSnapshot] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: snapshotDir,
            includingPropertiesForKeys: nil
        ) else { return [] }

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> SessionSnapshot? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(SessionSnapshot.self, from: data)
            }
            .sorted(by: { $0.startedAt < $1.startedAt })
    }

    // MARK: - Private

    private static func snapshotURL(for sessionId: String) -> URL {
        snapshotDir.appendingPathComponent("\(sessionId).json")
    }
}
