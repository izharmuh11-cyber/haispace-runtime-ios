import Foundation

public final class BackgroundSyncClient: @unchecked Sendable {
    public static let shared = BackgroundSyncClient()
    
    private init() {}
    
    public func triggerSync() {
        // No-op for now. In Phase 3, this will trigger the background sync worker.
        print("[BackgroundSyncClient] Sync triggered")
    }
}
