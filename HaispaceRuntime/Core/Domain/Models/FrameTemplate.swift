// FrameTemplate.swift
// HaispaceRuntime — Core/Domain/Models
//
// M-012: Definisi template komposisi frame.
//
// PRINSIP:
//   FrameTemplate mendefinisikan BAGAIMANA foto ditempatkan dalam sebuah frame.
//   Ini adalah pure data — tidak ada CoreImage, tidak ada UIKit, tidak ada rendering.
//   Engine (CoreImageEditingRuntime) yang mengonsumsi template ini.
//
// SATU FRAME = SATU TEMPLATE = N SLOT
//
// Contoh:
//   Frame "Classic White" (1 foto):    1 slot, seluruh area
//   Frame "Duo Strip"    (2 foto):     2 slot, susun vertikal
//   Frame "Quad Grid"    (4 foto):     4 slot, grid 2x2

import Foundation
import CoreGraphics

// MARK: - FrameTemplate

/// Template komposisi untuk satu frame overlay.
/// Mendefinisikan slot (area tempat foto masuk) beserta ukuran canvas.
public struct FrameTemplate: Codable, Sendable, Equatable {
    /// Referensi ke file frame (PNG overlay)
    public let frame: FrameReference
    
    /// Ukuran canvas output akhir (pixels)
    /// Semua koordinat slot bersifat relatif terhadap canvas ini.
    public let canvasWidth: CGFloat
    public let canvasHeight: CGFloat
    
    /// Daftar slot dalam template (urutan = urutan foto yang dimasukkan)
    public let slots: [TemplateSlot]
    
    public init(frame: FrameReference, canvasWidth: CGFloat, canvasHeight: CGFloat, slots: [TemplateSlot]) {
        self.frame = frame
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.slots = slots
    }
    
    /// Jumlah foto yang dibutuhkan oleh template ini
    public var requiredPhotoCount: Int { slots.count }
    
    public var canvasSize: CGSize { CGSize(width: canvasWidth, height: canvasHeight) }
}

// MARK: - TemplateSlot

/// Satu area di dalam FrameTemplate tempat satu foto akan ditempatkan.
/// Koordinat dalam pixels, relatif terhadap canvas kiri-atas (0,0).
public struct TemplateSlot: Codable, Sendable, Equatable {
    public let id: String
    
    /// Posisi dan ukuran slot dalam canvas (pixels)
    public let x: CGFloat
    public let y: CGFloat
    public let width: CGFloat
    public let height: CGFloat
    
    /// Rotasi slot (derajat) — biasanya 0, bisa berbeda untuk template artistic
    public let rotationDegrees: CGFloat
    
    /// Default crop behavior: center gravity
    public let cropGravityX: CGFloat   // 0.0 (kiri) – 1.0 (kanan)
    public let cropGravityY: CGFloat   // 0.0 (atas) – 1.0 (bawah)
    
    public init(
        id: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        rotationDegrees: CGFloat = 0,
        cropGravityX: CGFloat = 0.5,
        cropGravityY: CGFloat = 0.5
    ) {
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.rotationDegrees = rotationDegrees
        self.cropGravityX = cropGravityX
        self.cropGravityY = cropGravityY
    }
    
    /// Konversi ke FrameSlot (untuk FrameMaskCompositor)
    public var asFrameSlot: FrameSlot {
        FrameSlot(id: id, x: x, y: y, width: width, height: height, rotationDegrees: rotationDegrees)
    }
    
    /// Konversi ke SlotAdjustment (untuk FrameMaskCompositor)
    public var asSlotAdjustment: SlotAdjustment {
        SlotAdjustment(cropGravityX: cropGravityX, cropGravityY: cropGravityY, cropZoom: 1.0)
    }
}

// MARK: - Mock Templates (untuk development & testing)

extension FrameTemplate {
    
    /// Template standar 1 foto — slot penuh memenuhi canvas (Classic White mock)
    public static func singlePhoto(frameId: String, assetPath: String) -> FrameTemplate {
        FrameTemplate(
            frame: FrameReference(frameId: frameId, assetPath: assetPath),
            canvasWidth: 1080,
            canvasHeight: 1440,
            slots: [
                TemplateSlot(id: "slot-1", x: 36, y: 36, width: 1008, height: 1224)
            ]
        )
    }
    
    /// Template strip 2 foto — susun vertikal
    public static func dualStrip(frameId: String, assetPath: String) -> FrameTemplate {
        FrameTemplate(
            frame: FrameReference(frameId: frameId, assetPath: assetPath),
            canvasWidth: 1080,
            canvasHeight: 1440,
            slots: [
                TemplateSlot(id: "slot-1", x: 36,  y: 36,  width: 1008, height: 680),
                TemplateSlot(id: "slot-2", x: 36,  y: 724, width: 1008, height: 680)
            ]
        )
    }
    
    /// Template grid 4 foto — 2x2
    public static func quadGrid(frameId: String, assetPath: String) -> FrameTemplate {
        FrameTemplate(
            frame: FrameReference(frameId: frameId, assetPath: assetPath),
            canvasWidth: 1080,
            canvasHeight: 1440,
            slots: [
                TemplateSlot(id: "slot-1", x: 36,  y: 36,  width: 494, height: 680),
                TemplateSlot(id: "slot-2", x: 550, y: 36,  width: 494, height: 680),
                TemplateSlot(id: "slot-3", x: 36,  y: 724, width: 494, height: 680),
                TemplateSlot(id: "slot-4", x: 550, y: 724, width: 494, height: 680)
            ]
        )
    }
}
