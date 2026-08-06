import Foundation
import CoreImage

/// Protocol defining the contract for providing dynamic content to a SlotNode.
/// This prevents hardcoding a slot to only be a camera feed.
public protocol DynamicContentProvider {
    /// Request an image from this provider for the given slot identifier.
    /// - Parameters:
    ///   - slotId: The unique identifier of the slot requesting content.
    ///   - context: The current rendering context.
    /// - Returns: A CIImage if available.
    func image(for slotId: String, context: RenderContext) -> CIImage?
}

/// A standard implementation that pulls the CIImage directly from the SessionData's captured photos map.
public class SessionPhotoProvider: DynamicContentProvider {
    public init() {}
    
    public func image(for slotId: String, context: RenderContext) -> CIImage? {
        // Fallback or exact match logic can be expanded here
        return context.sessionData.capturedPhotos[slotId]
    }
}
