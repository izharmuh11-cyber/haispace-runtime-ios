import Foundation
import CoreImage

/// A dynamic layer node representing a photo or content slot in the template.
public class SlotNode: RenderNode {
    
    public let id: String
    public let zIndex: Int
    
    private let geometry: RenderGeometry
    private let cropParams: RenderCrop?
    private let contentProvider: DynamicContentProvider
    
    public init(id: String, zIndex: Int, geometry: RenderGeometry, cropParams: RenderCrop?, contentProvider: DynamicContentProvider) {
        self.id = id
        self.zIndex = zIndex
        self.geometry = geometry
        self.cropParams = cropParams
        self.contentProvider = contentProvider
    }
    
    public func render(context: RenderContext) -> CIImage? {
        // 1. Get raw content from the provider
        guard let sourceImage = contentProvider.image(for: id, context: context) else {
            return nil
        }
        
        let slotRect = CGRect(x: geometry.x, y: geometry.y, width: geometry.width, height: geometry.height)
        
        // 2. Delegate exact math to the Crop Engine
        return GravityCropEngine.applyCrop(
            to: sourceImage,
            targetSlot: slotRect,
            cropParams: cropParams
        )
    }
}
