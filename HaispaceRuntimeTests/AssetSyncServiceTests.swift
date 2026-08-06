import XCTest
import CryptoKit
@testable import HaispaceRuntime

class MockURLProtocol: URLProtocol {
    static var mockData: Data?
    static var mockResponse: HTTPURLResponse?
    static var mockError: Error?
    static var requestCount = 0
    
    override class func canInit(with request: URLRequest) -> Bool { return true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { return request }
    
    override func startLoading() {
        MockURLProtocol.requestCount += 1
        if let error = MockURLProtocol.mockError {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        if let response = MockURLProtocol.mockResponse {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        if let data = MockURLProtocol.mockData {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() {}
}

class MockLocalAssetStore: LocalAssetStoreProtocol {
    var registry: [String: LocalAsset] = [:]
    
    func getAsset(id: String) -> LocalAsset? { return registry[id] }
    func getAllAssets() -> [LocalAsset] { return Array(registry.values) }
    func saveAsset(asset: LocalAsset) throws { registry[asset.id] = asset }
    func deleteAsset(id: String) throws { registry.removeValue(forKey: id) }
    func baseDirectory() -> URL { return FileManager.default.temporaryDirectory }
}

final class AssetSyncServiceTests: XCTestCase {
    var sut: AssetSyncService!
    var mockStore: MockLocalAssetStore!
    var urlSession: URLSession!
    
    override func setUp() {
        super.setUp()
        mockStore = MockLocalAssetStore()
        
        MockURLProtocol.requestCount = 0
        MockURLProtocol.mockData = nil
        MockURLProtocol.mockResponse = nil
        MockURLProtocol.mockError = nil
        
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        urlSession = URLSession(configuration: config)
        
        sut = AssetSyncService(store: mockStore, urlSession: urlSession)
    }
    
    func testSyncSingleAsset_CacheMiss_DownloadsSuccessfully() async throws {
        // Arrange
        let fakeData = Data("fake_image_data".utf8)
        MockURLProtocol.mockData = fakeData
        MockURLProtocol.mockResponse = HTTPURLResponse(url: URL(string: "https://test.com/a.png")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        let hash = SHA256.hash(data: fakeData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        let cloudAsset = CloudAssetDTO(id: "1", role: "frame", name: "F1", assetType: "frame", downloadUrl: "https://test.com/a.png", checksum: hashString)
        
        // Act
        try await sut.syncAssets(from: [cloudAsset])
        
        // Assert
        XCTAssertEqual(MockURLProtocol.requestCount, 1)
        XCTAssertNotNil(mockStore.getAsset(id: "1"))
        XCTAssertEqual(mockStore.getAsset(id: "1")?.checksum, hashString)
    }
    
    func testSyncSingleAsset_CacheHit_SkipsDownload() async throws {
        // Arrange
        let fakeData = Data("fake_image_data".utf8)
        let hash = SHA256.hash(data: fakeData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        // Pre-populate mock store with exact checksum
        mockStore.registry["1"] = LocalAsset(id: "1", role: "frame", name: "F1", assetType: "frame", relativePath: "frame/1.png", checksum: hashString)
        
        let cloudAsset = CloudAssetDTO(id: "1", role: "frame", name: "F1", assetType: "frame", downloadUrl: "https://test.com/a.png", checksum: hashString)
        
        // Act
        try await sut.syncAssets(from: [cloudAsset])
        
        // Assert
        XCTAssertEqual(MockURLProtocol.requestCount, 0, "Should skip download when checksum matches (Delta Update)")
    }
    
    func testSyncSingleAsset_ChecksumMismatch_ThrowsError() async throws {
        // Arrange
        let fakeData = Data("fake_image_data".utf8)
        MockURLProtocol.mockData = fakeData
        MockURLProtocol.mockResponse = HTTPURLResponse(url: URL(string: "https://test.com/a.png")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        let cloudAsset = CloudAssetDTO(id: "1", role: "frame", name: "F1", assetType: "frame", downloadUrl: "https://test.com/a.png", checksum: "invalid_checksum")
        
        // Act & Assert
        do {
            try await sut.syncAssets(from: [cloudAsset])
            XCTFail("Should throw checksumMismatch error")
        } catch {
            guard let syncError = error as? AssetSyncError else {
                XCTFail("Expected AssetSyncError")
                return
            }
            XCTAssertEqual(syncError, .checksumMismatch)
        }
    }
}
