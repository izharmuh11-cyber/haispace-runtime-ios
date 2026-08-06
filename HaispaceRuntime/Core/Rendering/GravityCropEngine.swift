import Foundation
import CoreGraphics
import CoreImage

/// Core mathematical engine for calculating absolute CGAffineTransforms based on relative gravity coordinates.
/// Strictly Side-Effect Free.
public struct GravityCropEngine {
    
    /// Calculates the sequence of transforms required to place a source image into a slot geometry
    /// based on gravity parameters, and applies it to the image.
    ///
    /// - Parameters:
    ///   - image: The raw CIImage to transform.
    ///   - slotRect: The exact geometry of the slot on the main canvas (x, y, width, height).
    ///   - cropParams: The relative parameters for gravity, zoom, and rotation.
    /// - Returns: A transformed and cropped CIImage ready for compositing.
    public static func applyCrop(
        to image: CIImage,
        targetSlot slotRect: CGRect,
        cropParams: RenderCrop?
    ) -> CIImage {
        
        let sourceSize = image.extent.size
        guard sourceSize.width > 0 && sourceSize.height > 0 else { return image }
        
        let gravityX = cropParams?.gravityX ?? 0.5
        let gravityY = cropParams?.gravityY ?? 0.5
        let zoom = cropParams?.zoom ?? 1.0
        let rotationDeg = cropParams?.rotation ?? 0.0
        
        // 1. Calculate Base Scale (Fit-to-cover)
        let scaleX = slotRect.width / sourceSize.width
        let scaleY = slotRect.height / sourceSize.height
        let baseScale = max(scaleX, scaleY) * zoom
        
        // 2. Calculate Scaled Size
        let scaledWidth = sourceSize.width * baseScale
        let scaledHeight = sourceSize.height * baseScale
        
        // 3. Calculate Translation based on Gravity (0.0 to 1.0)
        // Excess space that we can pan across
        let excessX = scaledWidth - slotRect.width
        let excessY = scaledHeight - slotRect.height
        
        // If gravityX = 0.0, we want to show the left edge, so panX = 0
        // If gravityX = 1.0, we want to show the right edge, so panX = -excessX
        let panX = -(excessX * gravityX)
        let panY = -(excessY * gravityY)
        
        // Transform Sequence:
        var transform = CGAffineTransform.identity
        
        // A. Move to destination slot coordinates and apply Pan
        transform = transform.translatedBy(x: slotRect.minX + panX, y: slotRect.minY + panY)
        
        // B. Apply Scale
        transform = transform.scaledBy(x: baseScale, y: baseScale)
        
        // Apply transform to image
        var transformedImage = image.transformed(by: transform)
        
        // C. Apply Rotation if specified (around the center of the slot)
        if rotationDeg != 0 {
            let rotationRad = rotationDeg * .pi / 180.0
            let slotCenterX = slotRect.midX
            let slotCenterY = slotRect.midY
            
            var rotTransform = CGAffineTransform.identity
            rotTransform = rotTransform.translatedBy(x: slotCenterX, y: slotCenterY)
            rotTransform = rotTransform.rotated(by: rotationRad)
            rotTransform = rotTransform.translatedBy(x: -slotCenterX, y: -slotCenterY)
            
            transformedImage = transformedImage.transformed(by: rotTransform)
        }
        
        // D. Finally, hard crop to the exact Slot Bounding Box
        // We crop to slotRect. If there's rotation, the visual slot bounds act as a window mask.
        return transformedImage.cropped(to: slotRect)
    }
}
