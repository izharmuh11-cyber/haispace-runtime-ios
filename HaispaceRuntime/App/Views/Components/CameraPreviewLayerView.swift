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
        // AVCaptureVideoPreviewLayer auto-updates with the session.
        // Fix orientation for landscape iPad kiosk.
        if let connection = uiView.previewLayer.connection,
           connection.isVideoOrientationSupported {
            connection.videoOrientation = .landscapeRight
        }
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
        }
    }
}
