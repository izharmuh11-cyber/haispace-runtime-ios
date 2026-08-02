// CoreImageEditingRuntime.swift
// HaispaceRuntime — Core/Capabilities/Editing
//
// M-012: Implementasi konkret EditingRuntimeProtocol menggunakan CoreImage.
//
// PRINSIP (Platform Baseline v1.0):
//   Runtime ini tidak mengetahui domain Haispace:
//   - Tidak tahu Session
//   - Tidak tahu Guest
//   - Tidak tahu Package
//   - Tidak tahu Payment
//
//   Input  : file path foto mentah + EditingConfiguration
//   Output : file path hasil komposisi ke disk
//
// PIPELINE:
//   1. Baca foto mentah dari disk → CIImage
//   2. Baca PNG frame dari assetPath → CIImage (opsional)
//   3. Composite: foto ditempatkan dalam slot (FrameMaskCompositor)
//   4. Frame PNG di-overlay di atas
//   5. Export ke JPEG/HEIC ke path output
//
// THREAD SAFETY:
//   CIContext bersifat reusable dan thread-safe jika dibuat satu kali.
//   Semua operasi berjalan di background Task (bukan MainActor).

import Foundation
import CoreImage
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

// MARK: - CoreImageEditingRuntime

/// Implementasi CoreImage dari EditingRuntimeProtocol.
/// Satu-satunya class yang boleh menyentuh CIContext, CIFilter, CIImage di codebase ini.
public final class CoreImageEditingRuntime: EditingRuntimeProtocol, @unchecked Sendable {
    
    // MARK: - CoreImage Context (Thread-Safe, reusable)
    // CIContext dibuat satu kali, dipakai berulang — ini adalah best practice CoreImage.
    private var ciContext: CIContext?
    private let compositor = FrameMaskCompositor()
    private let outputDirectory: URL
    
    // MARK: - Init
    
    public init() {
        // Output dir: ~/Library/Caches/HaispaceRendered/
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.outputDirectory = caches.appendingPathComponent("HaispaceRendered", isDirectory: true)
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - EditingRuntimeProtocol
    
    public func preparePipeline() async throws {
        // Buat CIContext dengan Metal GPU jika tersedia, fallback ke CPU
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false,   // Prefer GPU (Metal)
            .workingColorSpace: CGColorSpaceCreateDeviceRGB()
        ]
        self.ciContext = CIContext(options: options)
        HaispaceLogger.info("[M-012] CoreImage pipeline prepared (Metal GPU preferred)", category: "editing")
    }
    
    public func renderPreview(
        photoInput: String,
        configuration: EditingConfiguration,
        correlationId: CorrelationID
    ) async throws -> PreviewResult {
        let startTime = Date()
        
        // Preview: render pada resolusi 1/4 untuk kecepatan (live preview di FrameSelectionView)
        let previewScale: CGFloat = 0.25
        let outputPath = try await render(
            photoInput: photoInput,
            configuration: configuration,
            correlationId: correlationId,
            scale: previewScale,
            quality: 0.75,
            suffix: "_preview"
        )
        
        let durationMs = Date().timeIntervalSince(startTime) * 1000
        HaispaceLogger.info("[M-012] Preview rendered in \(String(format: "%.1f", durationMs))ms", category: "editing")
        
        return PreviewResult(
            photoId: PhotoID(rawValue: correlationId.rawValue),
            outputReference: outputPath,
            renderDurationMs: durationMs
        )
    }
    
    public func renderExport(
        photoInput: String,
        configuration: EditingConfiguration,
        correlationId: CorrelationID
    ) async throws -> ExportResult {
        let startTime = Date()
        
        // Export: resolusi penuh
        let outputPath = try await render(
            photoInput: photoInput,
            configuration: configuration,
            correlationId: correlationId,
            scale: 1.0,
            quality: configuration.jpegQuality,
            suffix: "_export"
        )
        
        let durationMs = Date().timeIntervalSince(startTime) * 1000
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputPath)[.size] as? Int64) ?? 0
        
        HaispaceLogger.info("[M-012] Export rendered in \(String(format: "%.1f", durationMs))ms — \(fileSize / 1024)KB", category: "editing")
        
        return ExportResult(
            photoId: PhotoID(rawValue: correlationId.rawValue),
            outputReference: outputPath,
            renderDurationMs: durationMs,
            fileSizeBytes: fileSize,
            exportFormat: configuration.exportFormat
        )
    }
    
    // MARK: - Core Render Pipeline (Private)
    
    private func render(
        photoInput: String,
        configuration: EditingConfiguration,
        correlationId: CorrelationID,
        scale: CGFloat,
        quality: Double,
        suffix: String
    ) async throws -> String {
        guard let context = ciContext else {
            throw EditingRuntimeError.pipelineNotPrepared
        }
        
        // 1. Baca foto mentah dari disk
        guard let sourceImage = CIImage(contentsOf: URL(fileURLWithPath: photoInput)) else {
            throw EditingRuntimeError.photoNotFound(path: photoInput)
        }
        
        let sourceSize = sourceImage.extent.size
        
        // 2. Tentukan ukuran canvas output
        //    Jika ada frame template, gunakan ukuran canvas template.
        //    Jika tidak, gunakan ukuran foto asli.
        let canvasSize: CGSize
        if let frameRef = configuration.frame {
            // Untuk sekarang, default canvas 3:4 portrait
            // M-012 enhancement: baca FrameTemplate dari registry
            canvasSize = CGSize(width: 1080 * scale, height: 1440 * scale)
        } else {
            canvasSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        }
        
        // 3. Buat canvas kosong (putih) sebagai base
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        
        // 4. Scale dan posisikan foto dalam canvas
        //    Jika ada frame, gunakan slot komposisi (FrameMaskCompositor)
        var compositeImage: CIImage
        
        if let frameRef = configuration.frame {
            // Composite dengan frame
            compositeImage = try composeWithFrame(
                sourceImage: sourceImage,
                frameRef: frameRef,
                canvasSize: canvasSize,
                scale: scale,
                context: context
            )
        } else {
            // Tanpa frame: scale foto ke canvas
            let scaleX = canvasSize.width / sourceSize.width
            let scaleY = canvasSize.height / sourceSize.height
            let fitScale = min(scaleX, scaleY)
            let scaledWidth = sourceSize.width * fitScale
            let scaledHeight = sourceSize.height * fitScale
            let offsetX = (canvasSize.width - scaledWidth) / 2
            let offsetY = (canvasSize.height - scaledHeight) / 2
            
            compositeImage = sourceImage
                .transformed(by: CGAffineTransform(scaleX: fitScale, y: fitScale))
                .transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))
                .cropped(to: canvasRect)
        }
        
        // 5. Export ke disk
        let outputFilename = "\(correlationId.rawValue)\(suffix).jpg"
        let outputURL = outputDirectory.appendingPathComponent(outputFilename)
        
        try writeJPEG(image: compositeImage, to: outputURL, quality: quality, context: context, canvasSize: canvasSize)
        
        return outputURL.path
    }
    
    // MARK: - Frame Compositing
    
    private func composeWithFrame(
        sourceImage: CIImage,
        frameRef: FrameReference,
        canvasSize: CGSize,
        scale: CGFloat,
        context: CIContext
    ) throws -> CIImage {
        let sourceSize = sourceImage.extent.size
        
        // Default single-photo slot: padding 36px dari tepi
        let paddingScaled = 36.0 * scale
        let slot = FrameSlot(
            id: "slot-1",
            x: paddingScaled,
            y: paddingScaled,
            width: canvasSize.width - (paddingScaled * 2),
            height: canvasSize.height - (paddingScaled * 2)
        )
        let adjustment = SlotAdjustment(cropGravityX: 0.5, cropGravityY: 0.5, cropZoom: 1.0)
        
        // Hitung posisi foto dalam slot (FrameMaskCompositor dari SnapBooth legacy)
        let drawRect = compositor.calculateAutoFitRect(
            imageSize: sourceSize,
            slot: slot,
            adjustment: adjustment
        )
        
        // Scale dan posisikan foto
        let scaleX = drawRect.drawWidth / sourceSize.width
        let scaleY = drawRect.drawHeight / sourceSize.height
        
        var positioned = sourceImage
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .transformed(by: CGAffineTransform(translationX: drawRect.drawX, y: drawRect.drawY))
            .cropped(to: drawRect.clipSlotRect)
        
        // Overlay PNG frame jika tersedia di disk
        if FileManager.default.fileExists(atPath: frameRef.assetPath),
           let frameImage = CIImage(contentsOf: URL(fileURLWithPath: frameRef.assetPath)) {
            let frameScaled = frameImage.transformed(by: CGAffineTransform(
                scaleX: canvasSize.width / frameImage.extent.width,
                y: canvasSize.height / frameImage.extent.height
            ))
            // Frame di-overlay di atas foto (source-over compositing)
            positioned = frameScaled.composited(over: positioned)
        }
        
        // Crop ke canvas
        return positioned.cropped(to: CGRect(origin: .zero, size: canvasSize))
    }
    
    // MARK: - JPEG Write
    
    private func writeJPEG(
        image: CIImage,
        to url: URL,
        quality: Double,
        context: CIContext,
        canvasSize: CGSize
    ) throws {
        // Pastikan image di-clamp ke canvas agar tidak ada koordinat negatif
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        let clamped = image.clamped(to: canvasRect)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        if #available(iOS 17.0, *) {
            // iOS 17+: gunakan writeJPEGRepresentation langsung
            try context.writeJPEGRepresentation(
                of: clamped,
                to: url,
                colorSpace: colorSpace,
                options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: quality]
            )
        } else {
            // Fallback untuk iOS 16
            guard let cgImage = context.createCGImage(clamped, from: canvasRect) else {
                throw EditingRuntimeError.renderFailed(reason: "CIContext failed to create CGImage")
            }
            let data = NSMutableData()
            guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
                throw EditingRuntimeError.renderFailed(reason: "CGImageDestination creation failed")
            }
            let props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
            CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
            guard CGImageDestinationFinalize(dest) else {
                throw EditingRuntimeError.renderFailed(reason: "CGImageDestination finalize failed")
            }
            try (data as Data).write(to: url)
        }
    }
}

// MARK: - Runtime Errors

enum EditingRuntimeError: Error, LocalizedError {
    case pipelineNotPrepared
    case photoNotFound(path: String)
    case frameAssetNotFound(path: String)
    case renderFailed(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .pipelineNotPrepared:
            return "CoreImage pipeline belum diinisialisasi. Panggil preparePipeline() terlebih dahulu."
        case .photoNotFound(let path):
            return "File foto tidak ditemukan: \(path)"
        case .frameAssetNotFound(let path):
            return "Frame asset PNG tidak ditemukan: \(path)"
        case .renderFailed(let reason):
            return "Render gagal: \(reason)"
        }
    }
}
