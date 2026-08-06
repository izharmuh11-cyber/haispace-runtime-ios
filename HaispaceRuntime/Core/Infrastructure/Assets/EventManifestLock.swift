import Foundation

/// Locks the event's manifest version into memory/disk to prevent mid-event alterations from ruining consistency.
public class EventManifestLock {
    
    private var lockedManifestVersion: Int?
    private var lockedEventId: String?
    
    public init() {}
    
    /// Called when the Kiosk boots up and the event officially starts (Customer capture screen is active).
    public func lock(eventId: String, version: Int) {
        self.lockedEventId = eventId
        self.lockedManifestVersion = version
        print("🔒 Event \(eventId) LOCKED at Manifest Version \(version). Mid-event updates will be ignored.")
    }
    
    /// Checks if a newly downloaded or pushed manifest is allowed to be applied.
    public func canApplyUpdate(forEvent eventId: String, newVersion: Int) -> Bool {
        // If we haven't locked anything, we can apply
        guard let currentEvent = lockedEventId, let currentVersion = lockedManifestVersion else {
            return true
        }
        
        // If it's a different event, we shouldn't apply it to the current lock context anyway
        if currentEvent != eventId {
            return false
        }
        
        // If it's the exact same version, it's fine (no-op)
        if currentVersion == newVersion {
            return true
        }
        
        // If the event is currently locked, DO NOT allow version bumps mid-event
        print("⚠️ BLOCKED: Attempted to update to Manifest v\(newVersion) while Event \(currentEvent) is locked at v\(currentVersion).")
        return false
    }
    
    /// Unlocks the event, usually called by an Operator via Mission Control at the end of the day.
    public func unlock() {
        self.lockedEventId = nil
        self.lockedManifestVersion = nil
    }
}
