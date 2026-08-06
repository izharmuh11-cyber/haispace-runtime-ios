import Foundation
import CoreImage

public enum RenderEngineError: Error {
    case emptyNodeTree
    case compositeFailed
}

public class RenderEngine {
    
    private let ciContext: CIContext
    private var nodes: [RenderNode] = []
    
    public init(ciContext: CIContext = CIContext(options: [.useSoftwareRenderer: false])) {
        self.ciContext = ciContext
    }
    
    /// Loads a layout from the manifest into the rendering graph.
    /// In a real implementation, this would instantiate the correct `RenderNode` subclass
    /// (ImageNode, SlotNode, TextNode) based on the `FrameLayer` definitions.
    public func load(layout: FrameLayout) {
        // Placeholder for mapping FrameLayout to nodes.
        // E.g., self.nodes = layout.layers.map { createNode(from: $0) }
        self.nodes = []
    }
    
    /// Inserts a node dynamically into the engine (e.g. at runtime)
    public func add(node: RenderNode) {
        nodes.append(node)
    }
    
    /// Clears the engine graph
    public func clear() {
        nodes.removeAll()
    }
    
    /// Executes the render pass across the Node Tree.
    /// Returns the final composited image.
    public func render(targetSize: CGSize, sessionData: SessionBindingData, assetDirectory: URL) throws -> CIImage {
        guard !nodes.isEmpty else {
            throw RenderEngineError.emptyNodeTree
        }
        
        // 1. Sort nodes strictly by zIndex (asc)
        let sortedNodes = nodes.sorted { $0.zIndex < $1.zIndex }
        
        let context = RenderContext(
            ciContext: ciContext,
            targetSize: targetSize,
            sessionData: sessionData,
            assetDirectory: assetDirectory
        )
        
        // 2. Base transparent canvas
        var accumulator = CIImage(color: CIColor.clear).cropped(to: CGRect(origin: .zero, size: targetSize))
        
        guard let compositeFilter = CIFilter(name: "CISourceOverCompositing") else {
            throw RenderEngineError.compositeFailed
        }
        
        // 3. Composite each node iteratively
        for node in sortedNodes {
            if let layerImage = node.render(context: context) {
                compositeFilter.setValue(layerImage, forKey: kCIInputImageKey) // foreground
                compositeFilter.setValue(accumulator, forKey: kCIInputBackgroundImageKey) // background
                
                if let output = compositeFilter.outputImage {
                    accumulator = output
                }
            }
        }
        
        return accumulator
    }
}
