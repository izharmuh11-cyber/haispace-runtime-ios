import XCTest
import CoreImage
@testable import HaispaceRuntime

final class GravityCropEngineTests: XCTestCase {
    
    var dummySourceImage: CIImage!
    let targetSlot = CGRect(x: 100, y: 100, width: 400, height: 400)
    
    override func setUp() {
        super.setUp()
        // Create a solid 1000x500 dummy image to represent a 2:1 camera feed
        let color = CIColor(red: 1, green: 0, blue: 0)
        dummySourceImage = CIImage(color: color).cropped(to: CGRect(x: 0, y: 0, width: 1000, height: 500))
    }
    
    func testCenterCrop() {
        let params = RenderCrop(gravityX: 0.5, gravityY: 0.5, zoom: 1.0, rotation: 0.0)
        
        let output = GravityCropEngine.applyCrop(to: dummySourceImage, targetSlot: targetSlot, cropParams: params)
        
        // Output must precisely match target slot dimension
        XCTAssertEqual(output.extent.width, 400)
        XCTAssertEqual(output.extent.height, 400)
        
        // Because source is 1000x500 and target is 400x400
        // Base scale to fit 400 height = 400/500 = 0.8
        // Scaled width = 1000 * 0.8 = 800
        // Excess X = 800 - 400 = 400
        // Gravity 0.5 means shift X by -200
    }
    
    func testLeftExtremeCrop() {
        let params = RenderCrop(gravityX: 0.0, gravityY: 0.5, zoom: 1.0, rotation: 0.0)
        let output = GravityCropEngine.applyCrop(to: dummySourceImage, targetSlot: targetSlot, cropParams: params)
        XCTAssertEqual(output.extent, targetSlot)
    }
    
    func testZoomCrop() {
        let params = RenderCrop(gravityX: 0.5, gravityY: 0.5, zoom: 1.5, rotation: 0.0)
        let output = GravityCropEngine.applyCrop(to: dummySourceImage, targetSlot: targetSlot, cropParams: params)
        XCTAssertEqual(output.extent, targetSlot)
    }
    
    func testRotation() {
        let params = RenderCrop(gravityX: 0.5, gravityY: 0.5, zoom: 1.0, rotation: 15.0)
        let output = GravityCropEngine.applyCrop(to: dummySourceImage, targetSlot: targetSlot, cropParams: params)
        XCTAssertEqual(output.extent, targetSlot)
    }
}
