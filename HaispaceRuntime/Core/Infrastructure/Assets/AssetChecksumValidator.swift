import Foundation
import CryptoKit

public enum ChecksumError: Error {
    case fileNotFound
    case unreadableData
    case checksumMismatch(expected: String, actual: String)
}

/// Computes and verifies SHA256 hashes of downloaded .hspasset files.
public struct AssetChecksumValidator {
    
    public static func validate(fileURL: URL, expectedChecksum: String) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ChecksumError.fileNotFound
        }
        
        let fileData: Data
        do {
            fileData = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        } catch {
            throw ChecksumError.unreadableData
        }
        
        let hash = SHA256.hash(data: fileData)
        let actualChecksum = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        guard actualChecksum.lowercased() == expectedChecksum.lowercased() else {
            throw ChecksumError.checksumMismatch(expected: expectedChecksum, actual: actualChecksum)
        }
    }
}
