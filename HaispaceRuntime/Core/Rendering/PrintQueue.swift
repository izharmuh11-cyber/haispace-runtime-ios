import Foundation

public enum PrintQueueError: Error {
    case printerNotReady(PrinterStatus)
    case jobNotFound
}

/// A decoupled async queue that protects the camera capture loop from mechanical printer delays.
public class PrintQueue {
    
    private let printer: PrinterAdapter
    private var pendingJobs: [RenderJob] = []
    
    // Concurrent queue for managing print submissions without blocking main/camera threads
    private let queue = DispatchQueue(label: "com.haispace.printQueue", attributes: .concurrent)
    
    public init(printer: PrinterAdapter) {
        self.printer = printer
    }
    
    /// Submits a fully rendered job to the printer queue.
    /// Returns immediately. The job will be picked up asynchronously.
    public func enqueue(job: RenderJob) {
        queue.async(flags: .barrier) {
            var newJob = job
            newJob.transition(to: .readyToPrint)
            self.pendingJobs.append(newJob)
            
            // Trigger processing
            self.processNext()
        }
    }
    
    /// Triggers a retry for a specific job that was previously stuck in .retryPending
    public func retry(jobId: UUID) {
        queue.async(flags: .barrier) {
            if let index = self.pendingJobs.firstIndex(where: { $0.id == jobId }) {
                self.pendingJobs[index].transition(to: .readyToPrint)
                self.processNext()
            }
        }
    }
    
    private func processNext() {
        guard let jobIndex = pendingJobs.firstIndex(where: { $0.status == .readyToPrint }) else {
            return
        }
        
        let status = printer.status
        guard status == .ready else {
            // Cannot print. Mark as retryPending
            pendingJobs[jobIndex].transition(to: .retryPending, error: PrintQueueError.printerNotReady(status))
            return
        }
        
        var job = pendingJobs[jobIndex]
        job.transition(to: .printing)
        pendingJobs[jobIndex] = job
        
        Task {
            do {
                try await printer.print(job: job)
                // On success
                self.queue.async(flags: .barrier) {
                    if let idx = self.pendingJobs.firstIndex(where: { $0.id == job.id }) {
                        self.pendingJobs[idx].transition(to: .completed)
                    }
                }
            } catch {
                // On failure (jammed halfway etc)
                self.queue.async(flags: .barrier) {
                    if let idx = self.pendingJobs.firstIndex(where: { $0.id == job.id }) {
                        self.pendingJobs[idx].transition(to: .retryPending, error: error)
                    }
                }
            }
        }
    }
}
