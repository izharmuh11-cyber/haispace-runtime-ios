// CapturedPhotoStore.swift
// HaispaceRuntime — Core/State
//
// Bridge antara CameraCapabilityService (Capability Layer)
// dan View Layer (PhotoSelectionView) untuk M-008.
//
// Tugasnya sederhana: menyimpan referensi file foto yang berhasil diambil
// agar View bisa menampilkan hasilnya tanpa mengakses Capability Layer secara langsung.
//
// PRINSIP:
//   View membaca dari sini.
//   WorkflowOrchestrator menulis ke sini (via AppState.send).
//   CameraCapabilityService tidak pernah diakses langsung oleh View.

import Foundation
import Observation

@Observable
@MainActor
public final class CapturedPhotoStore {
    public static let shared = CapturedPhotoStore()
    
    // File path hasil capture dari CapturePipeline
    public private(set) var capturedPhotoPaths: [String] = []
    
    // Latest capture (untuk PhotoSelectionView / ReviewView)
    public var latestCapturedPhotoPath: String? {
        capturedPhotoPaths.last
    }
    
    private init() {}
    
    public func appendCapture(path: String) {
        capturedPhotoPaths.append(path)
        RuntimeTimelineLogger.shared.logEvent("CAPTURE_STORED", payload: path)
    }
    
    public func clearCaptures() {
        capturedPhotoPaths.removeAll()
    }
}
