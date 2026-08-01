// CameraPreviewView.swift
// HaispaceRuntime — App/Views/Guest
//
// ATURAN ARSITEKTUR:
// View ini TIDAK mengimpor AVFoundation.
// View ini HANYA mengonsumsi CGImage dari PreviewPipeline (Capability Layer).
// Hardware sepenuhnya tersembunyi di balik CameraCapabilityService.

import SwiftUI

/// View yang menampilkan live camera preview dari CameraCapabilityService.
/// Menggunakan `Image` dari `AsyncStream<CGImage>` — tidak ada AVFoundation di sini.
struct CameraPreviewView: View {
    @State private var currentFrame: CGImage?
    
    var body: some View {
        Group {
            if let frame = currentFrame {
                Image(decorative: frame, scale: 1.0, orientation: .up)
                    .resizable()
                    .scaledToFill()
                    .clipped()
                    .scaleEffect(x: -1, y: 1) // Horizontal mirror for selfie view
            } else {
                ZStack {
                    Color.black
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("Menyiapkan Kamera...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
        .task {
            await startPreviewStream()
        }
    }
    
    private func startPreviewStream() async {
        // Prepare camera if not yet done
        let svc = CameraCapabilityService.shared
        let health = await svc.healthSnapshot
        if health.status != .ready {
            try? await svc.prepare(configuration: .init())
        }
        
        // Consume frame stream from Capability Layer (CGImage, no AVFoundation in view)
        for await frame in await svc.previewPipeline.frameStream {
            await MainActor.run {
                currentFrame = frame
            }
        }
    }
}
