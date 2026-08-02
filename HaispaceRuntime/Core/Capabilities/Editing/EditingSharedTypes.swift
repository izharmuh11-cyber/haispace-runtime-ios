// EditingSharedTypes.swift
// HaispaceRuntime — Core/Capabilities/Editing
//
// Value Objects & Data Structs khusus untuk Editing Domain.
// Mendukung operasi deterministik f(Input, Config) -> Output.

import Foundation

/// Value Object Identifikasi Frame Overlay
public struct FrameReference: Hashable, Codable, Sendable {
    public let frameId: String
    public let assetPath: String
    
    public init(frameId: String, assetPath: String) {
        self.frameId = frameId
        self.assetPath = assetPath
    }
}

/// Value Object Identifikasi Metal LUT Filter
public struct FilterReference: Hashable, Codable, Sendable {
    public let filterId: String
    public let lutFileName: String
    public let intensity: Double // 0.0 s/d 1.0
    
    public init(filterId: String, lutFileName: String, intensity: Double = 1.0) {
        self.filterId = filterId
        self.lutFileName = lutFileName
        self.intensity = intensity
    }
}

/// Format Export Final
public enum ExportFormat: String, Codable, Sendable {
    case jpeg
    case heic
    case png
}

/// Hasil Render Preview Cepat
public struct PreviewResult: Codable, Sendable {
    public let photoId: PhotoID
    /// Path preview (resolusi rendah) — untuk ditampilkan di FrameSelectionView
    public let outputReference: String
    public let renderDurationMs: Double
    
    public init(photoId: PhotoID, outputReference: String, renderDurationMs: Double) {
        self.photoId = photoId
        self.outputReference = outputReference
        self.renderDurationMs = renderDurationMs
    }
}

/// Hasil Render Export Full Quality
/// M-012.5: Berisi RenderedOutput sebagai model kaya — bukan hanya path String.
/// Consumer (Printer, Cloud, Delivery, Gallery) menggunakan model ini secara langsung.
public struct ExportResult: Codable, Sendable {
    public let photoId: PhotoID
    public let rendered: RenderedOutput
    
    /// Compatibility accessor — untuk kode yang masih menggunakan outputReference: String
    public var outputReference: String { rendered.fullPath }
    public var renderDurationMs: Double { rendered.renderDurationMs }
    public var fileSizeBytes: Int64 { rendered.fileSizeBytes }
    public var exportFormat: ExportFormat
    
    public init(photoId: PhotoID, rendered: RenderedOutput, exportFormat: ExportFormat = .jpeg) {
        self.photoId = photoId
        self.rendered = rendered
        self.exportFormat = exportFormat
    }
}
