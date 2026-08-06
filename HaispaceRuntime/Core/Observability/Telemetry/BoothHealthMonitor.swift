import Foundation
import UIKit

/// The internal "doctor" that collects hardware and software metrics.
public class BoothHealthMonitor {
    
    private let boothId: String
    private let eventId: String
    private let printerAdapter: PrinterAdapter
    
    // In a real implementation, we would inject a queue manager to check pending jobs
    // private let printQueue: PrintQueue
    
    public init(boothId: String, eventId: String, printerAdapter: PrinterAdapter) {
        self.boothId = boothId
        self.eventId = eventId
        self.printerAdapter = printerAdapter
        
        UIDevice.current.isBatteryMonitoringEnabled = true
    }
    
    public func captureSnapshot() -> BoothHealthSnapshot {
        // Device Health
        let batteryLevel = Int(abs(UIDevice.current.batteryLevel) * 100)
        let isCharging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        
        var thermalStateString = "NORMAL"
        switch ProcessInfo.processInfo.thermalState {
        case .fair: thermalStateString = "FAIR"
        case .serious: thermalStateString = "SERIOUS"
        case .critical: thermalStateString = "CRITICAL"
        default: thermalStateString = "NORMAL"
        }
        
        let deviceHealth = DeviceHealth(
            batteryLevel: batteryLevel,
            isCharging: isCharging,
            thermalState: thermalStateString,
            networkType: "WIFI" // Placeholder for reachability
        )
        
        // Storage Health (Mocked for brevity, usually involves FileManager attributesOfFileSystem)
        let storageHealth = StorageHealth(
            usedPercentage: 75,
            availableGB: 64
        )
        
        // Hardware Health
        let hardwareHealth = HardwareHealth(
            camera: "READY",
            printer: printerAdapter.status.rawValue.uppercased(),
            storage: storageHealth,
            device: deviceHealth
        )
        
        // Software Health
        let softwareHealth = SoftwareHealth(
            manifestVersion: 1,
            pendingRenderJobs: 0 // Would read from CoreData or PrintQueue
        )
        
        return BoothHealthSnapshot(
            boothId: self.boothId,
            eventId: self.eventId,
            timestamp: Date(),
            status: "ONLINE",
            hardware: hardwareHealth,
            software: softwareHealth
        )
    }
}
