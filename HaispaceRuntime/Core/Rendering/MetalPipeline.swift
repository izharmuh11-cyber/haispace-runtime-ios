import Foundation
import MetalKit
import CoreImage

/// Connects the RenderEngine (CoreImage) directly to an MTKView (Metal) for zero-latency preview rendering.
public class MetalPipeline: NSObject, MTKViewDelegate {
    
    private let mtkView: MTKView
    private let commandQueue: MTLCommandQueue
    private let renderEngine: RenderEngine
    private let context: CIContext
    private let colorSpace: CGColorSpace
    
    // Dynamic binding to be passed each frame
    public var currentSessionData: SessionBindingData
    public var currentAssetDirectory: URL
    
    public init?(mtkView: MTKView, renderEngine: RenderEngine) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        
        self.mtkView = mtkView
        self.mtkView.device = device
        self.mtkView.framebufferOnly = false // Required for CoreImage rendering
        self.mtkView.colorPixelFormat = .bgra8Unorm // sRGB compliance
        
        self.commandQueue = commandQueue
        self.renderEngine = renderEngine
        
        // ADR-019: CIContext bound directly to Metal Device
        self.context = CIContext(mtlDevice: device, options: [
            .useSoftwareRenderer: false,
            .cacheIntermediates: false // optimize for 60fps streaming
        ])
        self.colorSpace = CGColorSpaceCreateDeviceRGB()
        
        self.currentSessionData = SessionBindingData()
        self.currentAssetDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        
        super.init()
        self.mtkView.delegate = self
    }
    
    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        // 1. Calculate target display size
        let targetSize = CGSize(width: view.drawableSize.width, height: view.drawableSize.height)
        
        // 2. Request a composed image from the RenderEngine Graph (ADR-019 Single Engine Rule)
        do {
            let compositedImage = try renderEngine.render(
                targetSize: targetSize,
                sessionData: currentSessionData,
                assetDirectory: currentAssetDirectory
            )
            
            // 3. Render directly into the Metal texture (Latency < 4ms)
            context.render(
                compositedImage,
                to: drawable.texture,
                commandBuffer: commandBuffer,
                bounds: CGRect(origin: .zero, size: targetSize),
                colorSpace: colorSpace
            )
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
            
        } catch {
            print("Preview render failed: \(error)")
        }
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle rotation or bounds change if necessary
    }
}
