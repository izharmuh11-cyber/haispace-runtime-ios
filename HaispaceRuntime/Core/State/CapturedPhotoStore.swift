// CapturedPhotoStore.swift
// HaispaceRuntime — Core/State
//
// M-011 STEP 1: CapturedPhotoStore adalah satu-satunya pemilik foto yang berhasil diambil.
//
// Prinsip:
//   Store ini tidak tahu apakah foto berasal dari P2P, AVFoundation, USB, atau Cloud.
//   Ia hanya menerima PhotoEvent — sebuah abstraksi yang membuat source tidak relevan.
//
//   Hari ini:   iPhone → P2P → PhotoEvent → CapturedPhotoStore
//   Besok:      iPad Camera → PhotoEvent → CapturedPhotoStore
//   Masa depan: DSLR / USB / Cloud → PhotoEvent → CapturedPhotoStore
//
// PRINSIP LAMA (M-008):
//   View membaca dari sini.
//   WorkflowOrchestrator menulis ke sini (via AppState.send).
//   CameraCapabilityService tidak pernah diakses langsung oleh View.

import Foundation
import Observation

// MARK: - PhotoEvent

/// Abstraksi event foto yang diterima dari sumber apapun.
/// CapturedPhotoStore tidak pernah tahu dari mana event ini berasal.
enum PhotoEvent {
    /// Thumbnail cepat tiba (Channel 1 — ~300KB)
    case thumbnailArrived(photoId: String, data: Data, capturedAt: Date, sortOrder: Int)
    /// Full quality tiba di background (Channel 2 — ~2-3MB)
    case fullQualityArrived(photoId: String, fullData: Data)
}

// MARK: - CapturedPhotoStore

@Observable
@MainActor
public final class CapturedPhotoStore {
    public static let shared = CapturedPhotoStore()
    
    // File path hasil capture dari CapturePipeline (native iPad camera)
    public private(set) var capturedPhotoPaths: [String] = []
    
    // Foto yang diterima via PhotoEvent (P2P / future sources)
    private(set) var capturedPhotos: [CapturedPhoto] = []
    
    // Latest capture (untuk PhotoSelectionView / ReviewView)
    public var latestCapturedPhotoPath: String? {
        capturedPhotoPaths.last
    }
    
    private init() {}
    
    // MARK: - Native Camera Path (iPad AVFoundation)
    
    public func appendCapture(path: String) {
        capturedPhotoPaths.append(path)
        RuntimeTimelineLogger.shared.logEvent("CAPTURE_STORED", payload: path)
    }
    
    public func clearCaptures() {
        capturedPhotoPaths.removeAll()
        capturedPhotos.removeAll()
    }
    
    // MARK: - PhotoEvent Path (M-011 STEP 1)
    
    /// Single entry point untuk semua sumber foto.
    /// Source (P2P, Camera, USB) memanggil ini — store tidak tahu siapa yang memanggil.
    func receivePhotoEvent(_ event: PhotoEvent) {
        switch event {
        case .thumbnailArrived(let photoId, let data, let capturedAt, let sortOrder):
            let photo = CapturedPhoto(
                id: photoId,
                thumbnailData: data,
                capturedAt: capturedAt,
                sortOrder: sortOrder
            )
            if let index = capturedPhotos.firstIndex(where: { $0.id == photoId }) {
                capturedPhotos[index] = photo
                HaispaceLogger.info("Foto \(photoId) sukses di-retake (ditimpa)!", category: "photo")
            } else {
                capturedPhotos.append(photo)
                capturedPhotos.sort { $0.sortOrder < $1.sortOrder }
                HaispaceLogger.info("Thumbnail diterima — foto ke-\(sortOrder + 1)", category: "photo")
            }
            
        case .fullQualityArrived(let photoId, let fullData):
            guard let photo = capturedPhotos.first(where: { $0.id == photoId }) else {
                HaispaceLogger.warning("fullQualityArrived: foto tidak ditemukan — \(photoId)", category: "photo")
                return
            }
            photo.upgradeToFull(data: fullData)
            HaispaceLogger.info("Full quality diterima untuk foto: \(photoId)", category: "photo")
        }
    }
}
