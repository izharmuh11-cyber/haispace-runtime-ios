import Foundation

public protocol TelemetryClient {
    func send(snapshot: BoothHealthSnapshot) async throws
}

/// Runs a background loop to constantly send heartbeats to the Cloud.
public class HeartbeatService {
    
    private let monitor: BoothHealthMonitor
    private let client: TelemetryClient
    
    private var timer: Timer?
    private var offlineBuffer: [BoothHealthSnapshot] = []
    
    // Concurrent queue to prevent network blocking the main thread
    private let queue = DispatchQueue(label: "com.haispace.heartbeatService", qos: .background)
    
    public init(monitor: BoothHealthMonitor, client: TelemetryClient) {
        self.monitor = monitor
        self.client = client
    }
    
    public func start(interval: TimeInterval = 10.0) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    public func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func tick() {
        queue.async {
            let snapshot = self.monitor.captureSnapshot()
            
            // Add to buffer first
            self.offlineBuffer.append(snapshot)
            
            Task {
                await self.flushBuffer()
            }
        }
    }
    
    private func flushBuffer() async {
        // Attempt to send all buffered snapshots (FIFO)
        var successfullySent = 0
        
        for snapshot in offlineBuffer {
            do {
                try await client.send(snapshot: snapshot)
                successfullySent += 1
            } catch {
                // If one fails (e.g. network down), stop flushing to preserve order
                print("Heartbeat send failed, buffering... \(error.localizedDescription)")
                break
            }
        }
        
        // Remove successfully sent items from buffer safely
        if successfullySent > 0 {
            queue.sync {
                self.offlineBuffer.removeFirst(successfullySent)
            }
        }
    }
}
