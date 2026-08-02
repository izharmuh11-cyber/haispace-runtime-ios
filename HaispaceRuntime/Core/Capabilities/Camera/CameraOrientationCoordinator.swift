// CameraOrientationCoordinator.swift
// HaispaceRuntime — Core/Capabilities/Camera

import Foundation
import UIKit
import AVFoundation

/// Centralized coordinator for determining camera orientation.
/// This acts as the single source of truth for all camera pipelines (Preview, Capture, Export),
/// decoupling AVFoundation from specific UI or device assumptions.
public actor CameraOrientationCoordinator {
    public static let shared = CameraOrientationCoordinator()
    
    private init() {}
    
    /// Returns the current runtime orientation for AVCaptureVideoOrientation.
    /// This is currently backed by UIDevice.current.orientation, but abstracts it away
    /// so that kiosks or external cameras can inject custom orientation providers.
    @MainActor
    public func currentVideoOrientation() -> AVCaptureVideoOrientation {
        let deviceOrientation = UIDevice.current.orientation
        
        switch deviceOrientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft // Phase 6A: Direct map
        case .landscapeRight:
            return .landscapeRight // Phase 6A: Direct map
        default:
            return .landscapeRight // Default for Haispace photobooths
        }
    }
    
    @MainActor
    public func currentVideoOrientationString() -> String {
        let orient = currentVideoOrientation()
        switch orient {
        case .portrait: return "Portrait"
        case .portraitUpsideDown: return "Portrait Upside Down"
        case .landscapeLeft: return "Landscape Left"
        case .landscapeRight: return "Landscape Right"
        @unknown default: return "Unknown"
        }
    }
}
