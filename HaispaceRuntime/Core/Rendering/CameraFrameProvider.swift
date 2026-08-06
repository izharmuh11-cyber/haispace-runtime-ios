import Foundation
import CoreImage
import AVFoundation

/// Provides the current live camera frame as a CIImage to be consumed by SlotNodes.
public class CameraFrameProvider: DynamicContentProvider {
    
    // The current CIImage extracted from CMSampleBuffer (in 720p/1080p preview resolution)
    private var currentFrame: CIImage?
    private let queue = DispatchQueue(label: "com.haispace.cameraFrameProvider")
    
    public init() {}
    
    /// Updates the current frame. Called repeatedly by AVCaptureVideoDataOutput delegate.
    public func updateFrame(_ ciImage: CIImage) {
        queue.sync {
            self.currentFrame = ciImage
        }
    }
    
    /// Retrieves the latest frame. If a slot ID requests content during Live Preview, it gets the camera feed.
    public func image(for slotId: String, context: RenderContext) -> CIImage? {
        // If during an active preview, sessionData might not have a hardcoded photo yet.
        // So we yield the live camera feed for all standard slots.
        var image: CIImage?
        queue.sync {
            image = self.currentFrame
        }
        return image
    }
    
    /// Locks and freezes the current frame for capture (Pipeline Transition: Capture ➔ Freeze)
    public func freezeCurrentFrame() -> CIImage? {
        var frozen: CIImage?
        queue.sync {
            frozen = self.currentFrame
        }
        return frozen
    }
}
