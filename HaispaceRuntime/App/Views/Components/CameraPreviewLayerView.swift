// CameraPreviewLayerView.swift
// HaispaceRuntime — App/Views/Components
//
// UIViewRepresentable yang membungkus AVCaptureVideoPreviewLayer.
// Ini adalah satu-satunya tempat di seluruh platform yang menyentuh
// UIKit untuk keperluan camera preview rendering.
//
// ALASAN: AVCaptureVideoPreviewLayer berjalan di GPU pipeline Apple.
// Jauh lebih efisien daripada mengkonversi setiap frame menjadi CGImage/UIImage
// untuk kiosk yang harus berjalan 8 jam tanpa overheating.
//
// VIEW LAYER: Tidak ada logika bisnis di sini. Hanya rendering.

import SwiftUI
import AVFoundation

public struct CameraPreviewLayerView: UIViewRepresentable {

    public let captureSession: AVCaptureSession

    public init(captureSession: AVCaptureSession) {
        self.captureSession = captureSession
    }

    public func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.backgroundColor = .black
        view.previewLayer.session = captureSession
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    public func updateUIView(_ uiView: PreviewUIView, context: Context) {
        // Update orientation dynamically
        uiView.updateOrientation()
    }

    // MARK: - PreviewUIView

    public final class PreviewUIView: UIView {
        public override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        public var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        public override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = bounds
            updateOrientation()
        }
        
        public func updateOrientation() {
            guard let connection = previewLayer.connection, connection.isVideoOrientationSupported else { return }
            
            let deviceOrientation = UIDevice.current.orientation
            let interfaceOrientation = window?.windowScene?.interfaceOrientation ?? .unknown
            
            let newVideoOrientation: AVCaptureVideoOrientation
            
            switch interfaceOrientation {
            case .portrait: newVideoOrientation = .portrait
            case .portraitUpsideDown: newVideoOrientation = .portraitUpsideDown
            case .landscapeLeft: newVideoOrientation = .landscapeLeft
            case .landscapeRight: newVideoOrientation = .landscapeRight
            default: newVideoOrientation = .landscapeRight
            }
            
            if connection.videoOrientation != newVideoOrientation {
                connection.videoOrientation = newVideoOrientation
                printRotationDiagnostic(device: deviceOrientation, interface: interfaceOrientation, connection: newVideoOrientation)
            }
        }
        
        private func printRotationDiagnostic(device: UIDeviceOrientation, interface: UIInterfaceOrientation, connection: AVCaptureVideoOrientation) {
            let deviceStr: String
            switch device {
            case .landscapeLeft: deviceStr = "Landscape Left"
            case .landscapeRight: deviceStr = "Landscape Right"
            case .portrait: deviceStr = "Portrait"
            case .portraitUpsideDown: deviceStr = "Portrait Upside Down"
            default: deviceStr = "Unknown/Flat"
            }
            
            let interfaceStr: String
            switch interface {
            case .landscapeLeft: interfaceStr = "Landscape Left"
            case .landscapeRight: interfaceStr = "Landscape Right"
            case .portrait: interfaceStr = "Portrait"
            case .portraitUpsideDown: interfaceStr = "Portrait Upside Down"
            default: interfaceStr = "Unknown"
            }
            
            let connStr: String
            switch connection {
            case .landscapeLeft: connStr = "Landscape Left"
            case .landscapeRight: connStr = "Landscape Right"
            case .portrait: connStr = "Portrait"
            case .portraitUpsideDown: connStr = "Portrait Upside Down"
            @unknown default: connStr = "Unknown"
            }
            
            let boundsStr = "\(Int(bounds.width))x\(Int(bounds.height))"
            
            let log = """
            =========================
            ROTATION DIAGNOSTIC
            =========================
            [1] Device: \(deviceStr)
            [2] UIWindowScene: \(interfaceStr)
            [3] AVCaptureConnection: \(connStr)
            [4] PreviewLayer Bounds: \(boundsStr)
            """
            
            RuntimeTimelineLogger.shared.logEvent("ROTATION_DIAGNOSTIC", payload: log)
        }
    }
}
