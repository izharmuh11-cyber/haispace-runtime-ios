import Foundation
import CoreImage

public protocol RenderNode {
    /// The unique identifier of this node
    var id: String { get }
    
    /// The explicit Z-Index to dictate rendering order (lower renders first)
    var zIndex: Int { get }
    
    /// Executes the rendering logic and returns a CoreImage representing this layer
    func render(context: RenderContext) -> CIImage?
}

/// A context passed down to all nodes during a render pass
public struct RenderContext {
    public let ciContext: CIContext
    public let targetSize: CGSize
    public let sessionData: SessionBindingData
    
    // Add paths or asset loaders here
    public let assetDirectory: URL
}

/// Payload containing dynamic data to bind (e.g. photos, text bindings)
public struct SessionBindingData {
    public let guestName: String?
    public let eventDate: String?
    
    /// Map of slot IDs to raw captured CIImages
    public let capturedPhotos: [String: CIImage]
    
    public init(guestName: String? = nil, eventDate: String? = nil, capturedPhotos: [String: CIImage] = [:]) {
        self.guestName = guestName
        self.eventDate = eventDate
        self.capturedPhotos = capturedPhotos
    }
}
