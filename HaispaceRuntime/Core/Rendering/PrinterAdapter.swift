import Foundation

/// Status of a connected physical printer (e.g. DNP, Sinfonia, Citizen)
public enum PrinterStatus: String, Codable {
    case ready
    case paperLow
    case overheating
    case offline
    case jammed
}

public protocol PrinterAdapter {
    /// Gets the real-time hardware status of the printer
    var status: PrinterStatus { get }
    
    /// Dispatches a job to the hardware printer.
    /// - Parameter job: The RenderJob containing the final exported image path
    func print(job: RenderJob) async throws
}
