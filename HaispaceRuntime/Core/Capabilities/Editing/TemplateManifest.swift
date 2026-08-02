// TemplateManifest.swift
// HaispaceRuntime — Core/Capabilities/Editing
//
// Model pembungkus untuk parsing template.json dari Asset Package.

import Foundation
import CoreGraphics

public struct TemplateManifest: Codable, Sendable, Equatable {
    public let canvas: Canvas
    public let bleed: EdgeInset?
    public let safeArea: EdgeInset?
    public let slots: [Slot]
    
    public struct Canvas: Codable, Sendable, Equatable {
        public let width: CGFloat
        public let height: CGFloat
        public let dpi: Int
        public let orientation: String
    }
    
    public struct EdgeInset: Codable, Sendable, Equatable {
        public let top: CGFloat
        public let bottom: CGFloat
        public let left: CGFloat
        public let right: CGFloat
    }
    
    public struct Slot: Codable, Sendable, Equatable {
        public let index: Int
        public let x: CGFloat
        public let y: CGFloat
        public let width: CGFloat
        public let height: CGFloat
        public let rotation: CGFloat
        public let zIndex: Int
    }
}
