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
        // Phase 6A.2: Use UIWindowScene as the source of truth, not physical device gyroscope.
        // This ensures the camera perfectly aligns with however the UI is being rendered.
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let interfaceOrientation = scene?.interfaceOrientation ?? .landscapeRight
        
        switch interfaceOrientation {
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
