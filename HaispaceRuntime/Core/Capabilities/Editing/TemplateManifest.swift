// TemplateManifest.swift
// HaispaceRuntime — Core/Capabilities/Editing
//
// Model pembungkus untuk parsing template.json dari Asset Package.

import Foundation
import CoreGraphics

public struct TemplateManifest: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let canvas: Canvas
    public let coordinateSystem: CoordinateSystem
    public let frameAssetId: String
    public let slots: [Slot]
    
    public struct Canvas: Codable, Sendable, Equatable {
        public let width: CGFloat
        public let height: CGFloat
    }
    
    public struct CoordinateSystem: Codable, Sendable, Equatable {
        public let origin: String
        public let unit: String
    }
    
    public struct Slot: Codable, Sendable, Equatable {
        public let id: String
        public let index: Int
        public let x: CGFloat
        public let y: CGFloat
        public let width: CGFloat
        public let height: CGFloat
        public let rotation: CGFloat
        public let borderRadius: CGFloat
        public let fit: String
    }
}
