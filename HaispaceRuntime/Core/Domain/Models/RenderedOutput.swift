// RenderedOutput.swift
// HaispaceRuntime — Core/Domain/Models
//
// M-012.5: Output model kaya dari Frame Engine.
//
// PRINSIP:
//   Satu model yang dipakai oleh semua consumer downstream:
//   - Printer     → pakai fullPath + widthPixels/heightPixels
//   - Cloud       → pakai fullPath + frameId
//   - Gallery     → pakai previewPath untuk thumbnail
//   - Delivery    → pakai id untuk tracking
//
// Consumer tidak perlu tahu cara render dilakukan.
// Mereka hanya perlu tahu apa hasilnya.

import Foundation

// MARK: - RenderedOutput

/// Output final dari Frame Engine setelah komposisi selesai.
/// Dipakai oleh Printer, Cloud, Gallery, dan Delivery tanpa modifikasi.
public struct RenderedOutput: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    
    /// Path preview (resolusi rendah, untuk UI — mungkin nil jika tidak di-render)
    public let previewPath: String?
    
    /// Path output full quality (resolusi penuh, untuk print dan cloud)
    public let fullPath: String
    
    /// Ukuran canvas hasil render (pixels)
    public let widthPixels: Int
    public let heightPixels: Int
    
    /// Durasi render total dalam milliseconds
    public let renderDurationMs: Double
    
    /// Timestamp saat render selesai
    public let createdAt: Date
    
    /// Frame yang digunakan (nil = tidak ada frame)
    public let frameId: String?
    
    /// Filter yang digunakan (nil = tidak ada filter)
    public let filterId: String?
    
    /// Ukuran file output dalam bytes
    public let fileSizeBytes: Int64
    
    public init(
        id: String = UUID().uuidString,
        previewPath: String? = nil,
        fullPath: String,
        widthPixels: Int,
        heightPixels: Int,
        renderDurationMs: Double,
        createdAt: Date = Date(),
        frameId: String? = nil,
        filterId: String? = nil,
        fileSizeBytes: Int64 = 0
    ) {
        self.id = id
        self.previewPath = previewPath
        self.fullPath = fullPath
        self.widthPixels = widthPixels
        self.heightPixels = heightPixels
        self.renderDurationMs = renderDurationMs
        self.createdAt = createdAt
        self.frameId = frameId
        self.filterId = filterId
        self.fileSizeBytes = fileSizeBytes
    }
    
    // MARK: - Computed
    
    public var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }
    
    public var renderDurationFormatted: String {
        String(format: "%.1fms", renderDurationMs)
    }
    
    public var resolution: String {
        "\(widthPixels)×\(heightPixels)"
    }
    
    public var aspectRatio: Double {
        guard heightPixels > 0 else { return 0 }
        return Double(widthPixels) / Double(heightPixels)
    }
}

// MARK: - PhotoReference

/// Referensi ringan ke foto yang akan dirender.
/// Digunakan oleh WorkflowOrchestrator untuk meneruskan foto ke EditingCapability
/// tanpa membawa dependency ke CapturedPhotoStore.
///
/// Prinsip: Orchestrator membaca dari store, lalu membungkusnya dalam PhotoReference.
/// EditingCapability dan CoreImageEditingRuntime tidak pernah menyentuh store langsung.
public struct PhotoReference: Codable, Sendable, Equatable {
    public let photoId: PhotoID
    
    /// Path file foto mentah di disk (input untuk rendering)
    public let sourcePath: String
    
    /// Ukuran asli foto (jika diketahui — membantu optimasi rendering)
    public let originalWidth: Int?
    public let originalHeight: Int?
    
    public init(photoId: PhotoID, sourcePath: String, originalWidth: Int? = nil, originalHeight: Int? = nil) {
        self.photoId = photoId
        self.sourcePath = sourcePath
        self.originalWidth = originalWidth
        self.originalHeight = originalHeight
    }
}
