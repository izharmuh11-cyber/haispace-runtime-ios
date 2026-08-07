// CoreImageEditingRuntime.swift
// HaispaceRuntime — Core/Capabilities/Editing
//
// M-012: Implementasi konkret EditingRuntimeProtocol menggunakan CoreImage.
// M-012.5: Fixed per Chief review:
//   ① outputDirectory di-inject dari luar (bukan hardcode internal)
//   ② Kembalikan RenderedOutput yang kaya (bukan bare String)
//   ③ Runtime tidak mengenal domain: Session, Guest, Package, Payment
//
// PIPELINE:
//   1. Baca foto mentah dari disk → CIImage
//   2. Baca PNG frame dari assetPath → CIImage (opsional)
//   3. Auto-fit foto ke slot (FrameMaskCompositor)
//   4. Frame PNG overlay di atas
//   5. Export JPEG ke outputDirectory yang di-inject

import Foundation
import CoreImage
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import UIKit

// MARK: - CoreImageEditingRuntime

/// Implementasi CoreImage dari EditingRuntimeProtocol.
///
/// YANG DIKETAHUI runtime ini:
///   - Cara membaca CIImage dari path
///   - Cara menempatkan foto dalam slot (via FrameMaskCompositor)
///   - Cara menulis JPEG ke path output yang diberikan
///
/// YANG TIDAK DIKETAHUI:
///   - Session, Guest, Package, Payment
///   - Folder convention (~/Library/Caches/...) — itu urusan caller
///   - CapturedPhotoStore
public final class CoreImageEditingRuntime: EditingRuntimeProtocol, @unchecked Sendable {
    
    // MARK: - CoreImage Context (Thread-Safe, reusable)
    private var ciContext: CIContext?
    private let compositor = FrameMaskCompositor()
    
    /// Direktori output untuk menyimpan hasil render.
    /// Di-inject dari luar — runtime tidak tahu ini ada di mana.
    private let outputDirectory: URL
    
    // MARK: - Init
    
    /// - Parameter outputDirectory: Direktori tempat file hasil render disimpan.
    ///   Caller (CapabilityModule) yang menentukan path ini.
    public init(outputDirectory: URL) {
        self.outputDirectory = outputDirectory
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - EditingRuntimeProtocol
    
    public func preparePipeline() async throws {
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false,
            .workingColorSpace: CGColorSpaceCreateDeviceRGB()
        ]
        self.ciContext = CIContext(options: options)
        HaispaceLogger.info("[M-012] CoreImage pipeline prepared (Metal GPU preferred)", category: "editing")
    }
    
    public func renderPreview(
        photoInputs: [String],
        configuration: EditingConfiguration,
        correlationId: CorrelationID
    ) async throws -> PreviewResult {
        let startTime = Date()
        let previewScale: CGFloat = 0.25
        
        let (outputPath, width, height) = try await render(
            photoInputs: photoInputs,
            configuration: configuration,
            correlationId: correlationId,
            scale: previewScale,
            quality: 0.75,
            suffix: "_preview",
            isPreview: true
        )
        
        let durationMs = Date().timeIntervalSince(startTime) * 1000
        HaispaceLogger.info("[M-012] Preview \(width)×\(height) in \(String(format: "%.1f", durationMs))ms", category: "editing")
        
        return PreviewResult(
            photoId: PhotoID(rawValue: correlationId.rawValue),
            outputReference: outputPath,
            renderDurationMs: durationMs
        )
    }
    
    public func renderExport(
        photoInputs: [String],
        configuration: EditingConfiguration,
        correlationId: CorrelationID
    ) async throws -> ExportResult {
        let startTime = Date()
        
        let (outputPath, width, height) = try await render(
            photoInputs: photoInputs,
            configuration: configuration,
            correlationId: correlationId,
            scale: 1.0,
            quality: configuration.jpegQuality,
            suffix: "_export",
            isPreview: false
        )
        
        let durationMs = Date().timeIntervalSince(startTime) * 1000
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputPath)[.size] as? Int64) ?? 0
        
        HaispaceLogger.info(
            "[M-012] Export \(width)×\(height) — \(fileSize / 1024)KB — \(String(format: "%.1f", durationMs))ms",
            category: "editing"
        )
        
        // M-012.5 ③: Kembalikan RenderedOutput yang kaya
        let rendered = RenderedOutput(
            previewPath: nil,
            fullPath: outputPath,
            widthPixels: width,
            heightPixels: height,
            renderDurationMs: durationMs,
            frameId: configuration.frame?.frameId,
            filterId: configuration.filter?.filterId,
            fileSizeBytes: fileSize
        )
        
        return ExportResult(
            photoId: PhotoID(rawValue: correlationId.rawValue),
            rendered: rendered,
            exportFormat: configuration.exportFormat
        )
    }
    
    // MARK: - Core Render Pipeline (Private)
    
    private func render(
        photoInputs: [String],
        configuration: EditingConfiguration,
        correlationId: CorrelationID,
        scale: CGFloat,
        quality: Double,
        suffix: String,
        isPreview: Bool
    ) async throws -> (path: String, width: Int, height: Int) {
        guard let context = ciContext else {
            throw EditingRuntimeError.pipelineNotPrepared
        }
        
        Task { @MainActor in
            RuntimeTimelineLogger.shared.logEvent("[RENDER][START] correlationId: \(correlationId.rawValue), photoInputsCount: \(photoInputs.count), isPreview: \(isPreview)")
        }
        
        var sourceSize: CGSize
        var firstSourceImage: CIImage?
        
        if let firstPhotoPath = photoInputs.first, let img = CIImage(contentsOf: URL(fileURLWithPath: firstPhotoPath)) {
            firstSourceImage = img
            sourceSize = img.extent.size
        } else {
            // Fallback to a transparent dummy image for frame-only preview
            firstSourceImage = nil
            sourceSize = CGSize(width: 1080, height: 1440) // Default typical size
        }
        
        var canvasSize: CGSize
        var templateManifest: TemplateManifest? = configuration.template
        
        if templateManifest == nil, let frameRef = configuration.frame {
            // Fallback lookup if template wasn't passed directly
            templateManifest = await TemplateStore.shared.templates.first(where: { $0.frameAssetId == frameRef.frameId })
        }
        
        if let manifest = templateManifest {
            canvasSize = CGSize(width: manifest.canvas.width * scale, height: manifest.canvas.height * scale)
        } else {
            canvasSize = CGSize(width: 1080 * scale, height: 1440 * scale)
        }
        
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        var compositeImage: CIImage
        
        if let frameRef = configuration.frame {
            compositeImage = try composeWithFrame(
                photoInputs: photoInputs,
                frameRef: frameRef,
                canvasSize: canvasSize,
                scale: scale,
                context: context,
                template: templateManifest
            )
        } else {
            let scaleX = canvasSize.width / sourceSize.width
            let scaleY = canvasSize.height / sourceSize.height
            let fitScale = min(scaleX, scaleY)
            let scaledW = sourceSize.width * fitScale
            let scaledH = sourceSize.height * fitScale
            let offsetX = (canvasSize.width - scaledW) / 2
            let offsetY = (canvasSize.height - scaledH) / 2
            
            let baseImg = firstSourceImage ?? CIImage(color: CIColor.clear).cropped(to: CGRect(origin: .zero, size: sourceSize))
            
            compositeImage = baseImg
                .transformed(by: CGAffineTransform(scaleX: fitScale, y: fitScale))
                .transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))
                .cropped(to: canvasRect)
        }
        
        let outputFilename = "\(correlationId.rawValue)\(suffix).jpg"
        let outputURL = outputDirectory.appendingPathComponent(outputFilename)
        
        try writeJPEG(image: compositeImage, to: outputURL, quality: quality, context: context, canvasSize: canvasSize)
        
        let exists = FileManager.default.fileExists(atPath: outputURL.path)
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
        let compositeDecode = UIImage(contentsOfFile: outputURL.path) != nil
        
        Task { @MainActor in
            RuntimeTimelineLogger.shared.logEvent("[RENDER][OUTPUT_PATH] path: \(outputURL.path), exists: \(exists), size: \(fileSize)")
            RuntimeTimelineLogger.shared.logEvent("[FORENSIC][TEMPLATE_RENDER] compositeExtent = \(Int(canvasSize.width))x\(Int(canvasSize.height))")
            RuntimeTimelineLogger.shared.logEvent("[FORENSIC][TEMPLATE_RENDER] outputFileExists = \(exists)")
            RuntimeTimelineLogger.shared.logEvent("[FORENSIC][TEMPLATE_RENDER] outputFileSize = \(fileSize)")
            RuntimeTimelineLogger.shared.logEvent("[FORENSIC][TEMPLATE_RENDER] compositeDecode = \(compositeDecode)")
        }
        
        return (
            path: outputURL.path,
            width: Int(canvasSize.width),
            height: Int(canvasSize.height)
        )
    }
    
    // MARK: - Frame Compositing
    
    private func composeWithFrame(
        photoInputs: [String],
        frameRef: FrameReference,
        canvasSize: CGSize,
        scale: CGFloat,
        context: CIContext,
        template: TemplateManifest?
    ) throws -> CIImage {
        
        // Base canvas is clear
        var canvasImage = CIImage(color: CIColor.clear).cropped(to: CGRect(origin: .zero, size: canvasSize))
        
        var frameSlots: [FrameSlot] = []
        
        if let template = template {
            // Convert TemplateManifest slots to FrameSlots
            for tSlot in template.slots {
                let slot = FrameSlot(
                    id: "slot-\(tSlot.index)",
                    x: tSlot.x * scale,
                    y: tSlot.y * scale,
                    width: tSlot.width * scale,
                    height: tSlot.height * scale,
                    rotationDegrees: tSlot.rotation
                )
                frameSlots.append(slot)
            }
        } else {
            // Fallback for missing template
            let paddingScaled = 36.0 * scale
            let slot = FrameSlot(
                id: "slot-1",
                x: paddingScaled,
                y: paddingScaled,
                width: canvasSize.width - (paddingScaled * 2),
                height: canvasSize.height - (paddingScaled * 2)
            )
            frameSlots.append(slot)
        }
        
        let adjustment = SlotAdjustment(cropGravityX: 0.5, cropGravityY: 0.5, cropZoom: 1.0)
        
        // INVARIANT: Transparent dummy is ONLY used for missing 'photos' (initial preview mode).
        // It MUST NOT be used to cover missing 'frames'. NO PHOTO ≠ ERROR, NO FRAME = ERROR.
        // Draw the source image into each slot
        for (index, slot) in frameSlots.enumerated() {
            // Gunakan foto yang sesuai dengan slot, atau fallback ke foto terakhir
            var sourceImage: CIImage? = nil
            if !photoInputs.isEmpty {
                let photoIndex = min(index, photoInputs.count - 1)
                if photoIndex >= 0 {
                    let photoPath = photoInputs[photoIndex]
                    sourceImage = CIImage(contentsOf: URL(fileURLWithPath: photoPath))
                }
            }
            
            // Default to transparent dummy image if no source is available
            let safeSourceImage = sourceImage ?? CIImage(color: CIColor.clear).cropped(to: CGRect(origin: .zero, size: CGSize(width: 1080, height: 1440)))
            let srcSize = safeSourceImage.extent.size
            
            let drawRect = compositor.calculateAutoFitRect(imageSize: srcSize, slot: slot, adjustment: adjustment)
            
            let scaleX = drawRect.drawWidth / srcSize.width
            let scaleY = drawRect.drawHeight / srcSize.height
            
            var positioned = safeSourceImage
                .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
                .transformed(by: CGAffineTransform(translationX: drawRect.drawX, y: drawRect.drawY))
                .cropped(to: drawRect.clipSlotRect)
            
            // Apply rotation around the center of the slot if needed
            if slot.rotationDegrees != 0 {
                // CIImage rotation is counter-clockwise in radians, centered at (0,0).
                // We need to translate to center, rotate, and translate back.
                let radians = slot.rotationDegrees * .pi / 180.0
                let centerX = slot.x + (slot.width / 2.0)
                let centerY = slot.y + (slot.height / 2.0)
                
                positioned = positioned
                    .transformed(by: CGAffineTransform(translationX: -centerX, y: -centerY))
                    .transformed(by: CGAffineTransform(rotationAngle: -radians)) // Negative because CIImage coords are bottom-left
                    .transformed(by: CGAffineTransform(translationX: centerX, y: centerY))
            }
            
            canvasImage = positioned.composited(over: canvasImage)
            
            // FORENSIC LOGGING for each slot
            Task { @MainActor in
                RuntimeTimelineLogger.shared.logEvent("[FORENSIC][TEMPLATE_RENDER] slot[\(index)] = \(slot.x), \(slot.y), \(slot.width), \(slot.height), \(slot.rotationDegrees)")
            }
        }
        
        Task { @MainActor in
            RuntimeTimelineLogger.shared.logEvent("[FORENSIC][TEMPLATE_RENDER] photoCount = \(photoInputs.count)")
            RuntimeTimelineLogger.shared.logEvent("[FORENSIC][TEMPLATE_RENDER] templateId = \(template?.id ?? "fallback")")
            RuntimeTimelineLogger.shared.logEvent("[FORENSIC][TEMPLATE_RENDER] canvas = \(canvasSize.width)x\(canvasSize.height)")
            RuntimeTimelineLogger.shared.logEvent("[FORENSIC][TEMPLATE_RENDER] slotCount = \(frameSlots.count)")
        }
        
        // Overlay the frame PNG
        // FORENSIC LOGGING
        Task { @MainActor in
            RuntimeTimelineLogger.shared.logEvent("[FORENSIC] Decoder Target Frame Path: \(frameRef.assetPath)")
        }
        
        let frameURL: URL
        if frameRef.assetPath.lowercased().hasSuffix(".png") {
            frameURL = URL(fileURLWithPath: frameRef.assetPath)
        } else {
            frameURL = URL(fileURLWithPath: frameRef.assetPath).appendingPathComponent("frame.png")
        }
        
        let frameExists = FileManager.default.fileExists(atPath: frameURL.path)
        let frameSize = (try? FileManager.default.attributesOfItem(atPath: frameURL.path)[.size] as? Int64) ?? 0
        Task { @MainActor in
            RuntimeTimelineLogger.shared.logEvent("[FORENSIC] Decoder Frame Image Exists: \(frameExists) | Bytes: \(frameSize) | URL: \(frameURL.path)")
        }
        
        if !frameExists {
            Task { @MainActor in
                RuntimeTimelineLogger.shared.logEvent("[FORENSIC][TEMPLATE_RENDER] frameDecode = false (File Missing)")
            }
            throw EditingRuntimeError.frameMissing(path: frameURL.path)
        }
        
        guard let frameImage = CIImage(contentsOf: frameURL) else {
            Task { @MainActor in
                RuntimeTimelineLogger.shared.logEvent("[FORENSIC][TEMPLATE_RENDER] frameDecode = false (Unreadable)")
            }
            throw EditingRuntimeError.frameUnreadable(path: frameURL.path)
        }
        
        Task { @MainActor in
            RuntimeTimelineLogger.shared.logEvent("[FORENSIC][TEMPLATE_RENDER] frameDecode = true")
        }
        
        let frameScaled = frameImage.transformed(by: CGAffineTransform(
            scaleX: canvasSize.width / frameImage.extent.width,
            y: canvasSize.height / frameImage.extent.height
        ))
        canvasImage = frameScaled.composited(over: canvasImage)
        
        return canvasImage.cropped(to: CGRect(origin: .zero, size: canvasSize))
    }
    
    // MARK: - JPEG Write
    
    private func writeJPEG(image: CIImage, to url: URL, quality: Double, context: CIContext, canvasSize: CGSize) throws {
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        let clamped = image.clamped(to: canvasRect)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        if #available(iOS 17.0, *) {
            try context.writeJPEGRepresentation(
                of: clamped,
                to: url,
                colorSpace: colorSpace,
                options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: quality]
            )
        } else {
            guard let cgImage = context.createCGImage(clamped, from: canvasRect) else {
                throw EditingRuntimeError.compositingFailed(reason: "CIContext failed to create CGImage")
            }
            let data = NSMutableData()
            guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
                throw EditingRuntimeError.compositingFailed(reason: "CGImageDestination creation failed")
            }
            CGImageDestinationAddImage(dest, cgImage, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
            guard CGImageDestinationFinalize(dest) else {
                throw EditingRuntimeError.compositingFailed(reason: "CGImageDestination finalize failed")
            }
            try (data as Data).write(to: url)
        }
    }
}

// MARK: - Runtime Errors

enum EditingRuntimeError: Error, LocalizedError {
    case pipelineNotPrepared
    case photoNotFound(path: String)
    case frameMissing(path: String)
    case frameUnreadable(path: String)
    case compositingFailed(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .pipelineNotPrepared:
            return "CoreImage pipeline belum diinisialisasi. Panggil preparePipeline() terlebih dahulu."
        case .photoNotFound(let path):
            return "File foto tidak ditemukan: \(path)"
        case .frameMissing(let path):
            return "Frame asset PNG tidak ditemukan secara fisik di lokal: \(path)"
        case .frameUnreadable(let path):
            return "Frame PNG gagal dibaca atau corrupt: \(path)"
        case .compositingFailed(let reason):
            return "Render komposit gagal: \(reason)"
        }
    }
}
