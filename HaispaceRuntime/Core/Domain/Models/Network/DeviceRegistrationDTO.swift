import Foundation

public struct DeviceRegistrationRequest: Encodable {
    public let boothId: String
    public let runtimeId: String
    public let architectureVersion: String
    public let platform: String
    public let deviceClass: String
    public let publicKey: String
    public let buildNumber: String
    
    public init(boothId: String, buildNumber: String) {
        self.boothId = boothId
        self.runtimeId = KeychainHelper.getOrCreateDeviceUUID()
        self.architectureVersion = "1.0"
        self.platform = "ipad"
        self.deviceClass = "Booth"
        self.publicKey = "not-implemented" // Untuk Fase berikutnya (E2E encryption)
        self.buildNumber = buildNumber
    }
}

public struct DeviceRegistrationResponse: Decodable {
    public let deviceId: String
    public let boothId: String
    public let runtimeId: String
    public let apiKey: String
}
