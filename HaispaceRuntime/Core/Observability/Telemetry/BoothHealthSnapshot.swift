import Foundation

public struct StorageHealth: Codable {
    public let usedPercentage: Int
    public let availableGB: Int
}

public struct DeviceHealth: Codable {
    public let batteryLevel: Int
    public let isCharging: Bool
    public let thermalState: String // NORMAL, FAIR, SERIOUS, CRITICAL
    public let networkType: String // WIFI, CELLULAR, NONE
}

public struct HardwareHealth: Codable {
    public let camera: String // READY, ERROR, DISCONNECTED
    public let printer: String // READY, PAPER_LOW, JAMMED, OFFLINE, OVERHEATING
    public let storage: StorageHealth
    public let device: DeviceHealth
}

public struct SoftwareHealth: Codable {
    public let manifestVersion: Int
    public let pendingRenderJobs: Int
}

public struct BoothHealthSnapshot: Codable {
    public let boothId: String
    public let eventId: String
    public let timestamp: Date
    public let status: String // ONLINE, OFFLINE
    
    public let hardware: HardwareHealth
    public let software: SoftwareHealth
}
