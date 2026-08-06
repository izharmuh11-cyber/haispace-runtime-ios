import Foundation
import CoreGraphics

public enum LayerType: String, Codable {
    case image = "image"
    case slot = "slot"
    case text = "text"
}

public struct RenderGeometry: Codable {
    public let x: CGFloat
    public let y: CGFloat
    public let width: CGFloat
    public let height: CGFloat
}

public struct RenderCrop: Codable {
    public let gravityX: CGFloat?
    public let gravityY: CGFloat?
    public let zoom: CGFloat?
    public let rotation: CGFloat?
}

public struct TextBinding: Codable {
    public let source: String // e.g., "guest.name"
}

public struct FrameLayer: Codable, Identifiable {
    public let id: String
    public let type: LayerType
    public let zIndex: Int
    
    // Properties based on layer type
    public let asset: String?      // for type == .image
    public let geometry: RenderGeometry? // for type == .slot
    public let crop: RenderCrop?   // for type == .slot
    public let textBinding: TextBinding? // for type == .text
}

public struct FrameLayout: Codable {
    public let canvas: RenderGeometry
    public let layers: [FrameLayer]
}

public struct FrameProductManifest: Codable {
    public let name: String
    public let layouts: [String: FrameLayout]
}
