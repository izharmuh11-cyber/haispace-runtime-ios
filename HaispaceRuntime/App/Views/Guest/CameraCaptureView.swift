// CameraCaptureView.swift
// HaispaceRuntime — UI/Views (Scene 3: The Moment)
//
// M-010: Kamera nyata. Preview nyata. Foto nyata.
//
// Camera Live Capture & Automatic Pose Countdown View Haispace Kiosk Photobooth.
// REVISION 2 — M-010 Real Camera Integration.
// - LIVE AVCaptureVideoPreviewLayer via CameraPreviewLayerView
// - REAL CAPTURE via CameraCapabilityService.requestCapture()
// - Camera permission request on appear
// - ZERO SHUTTER BUTTON: The System Moves First (Automatic 0.8s Orientation → Countdown)
// - State Machine Engine: enum CaptureStage (ready, guiding, countdown, flashing, reveal)
// - Visual AR Silhouette Pose Guide
// - Non-blocking Upper Eye-Line Countdown Typography

import SwiftUI
import AVFoundation

public struct CameraCaptureView: View {

    // Injected Action Intent
    private let onCaptureCompleted: (String) async -> Void

    // Explicit FSM Stage Engine
    private enum CaptureStage: Equatable {
        case permissionDenied
        case ready
        case guiding
        case countdown(Int)
        case capturing      // waiting for real capture to return
        case flashing
        case reveal
    }

    @State private var stage: CaptureStage = .ready
    @State private var sequenceTask: Task<Void, Never>? = nil
    @State private var captureSession: AVCaptureSession? = nil

    public init(onCaptureCompleted: @escaping (String) async -> Void) {
        self.onCaptureCompleted = onCaptureCompleted
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // LIVE CAMERA PREVIEW STAGE
            ZStack {
                // Live Camera Feed (replaces gradient placeholder)
                if let session = captureSession {
                    CameraPreviewLayerView(captureSession: session)
                        .ignoresSafeArea()
                } else {
                    // Fallback while permission/session is loading
                    Color(white: 0.06).ignoresSafeArea()
                }

                // Vignette
                RadialGradient(
                    gradient: Gradient(colors: [.clear, Color.black.opacity(stage == .ready ? 0.4 : 0.15)]),
                    center: .center,
                    startRadius: 150,
                    endRadius: 600
                )
                .animation(.easeInOut(duration: 0.3), value: stage)

                // Permission denied overlay
                if case .permissionDenied = stage {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.slash.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.7))
                        Text("Izin Kamera Diperlukan")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text("Buka Pengaturan → Haispace Runtime → Kamera")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                }

                // AR Silhouette Guide
                if stage == .guiding || isCountdownActive {
                    VStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                .frame(width: 80, height: 80)
                                .offset(y: -50)
                            Capsule()
                                .stroke(Color.white.opacity(0.25), lineWidth: 2)
                                .frame(width: 220, height: 90)
                                .offset(y: 30)
                        }
                        .shadow(color: .white.opacity(0.25), radius: 16)
                        .padding(.bottom, 80)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }

                // Countdown overlay
                if case .countdown(let val) = stage {
                    VStack {
                        Text("\(val)")
                            .font(.system(size: 110, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.6), radius: 16, x: 0, y: 8)
                            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: val)
                            .padding(.top, 40)
                        Spacer()
                    }
                }

                // Capturing spinner (waiting for AVFoundation)
                if case .capturing = stage {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(2)
                }

                // Shutter flash
                if stage == .flashing {
                    Color.white.ignoresSafeArea().transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            requestPermissionAndStart()
        }
        .onDisappear {
            sequenceTask?.cancel()
            // Stop the session when leaving this view
            Task {
                await CameraCapabilityService.shared.stopSession()
            }
        }
    }

    // MARK: - Permission & Session Setup

    private func requestPermissionAndStart() {
        Task {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .authorized:
                await startCameraSession()
            case .notDetermined:
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                if granted {
                    await startCameraSession()
                } else {
                    stage = .permissionDenied
                }
            default:
                stage = .permissionDenied
            }
        }
    }

    @MainActor
    private func startCameraSession() async {
        do {
            let config = CameraConfiguration(frameRate: 30)
            try await CameraCapabilityService.shared.prepare(configuration: config)
            // Expose the AVCaptureSession to the preview layer
            captureSession = CameraCapabilityService.shared.captureSession
            let sessionId = SessionID(rawValue: UUID().uuidString)
            try await CameraCapabilityService.shared.startSession(sessionId: sessionId)
            startAutomaticCaptureSequence()
        } catch {
            stage = .permissionDenied
        }
    }

    // MARK: - Automatic System Sequence Engine

    private var isCountdownActive: Bool {
        if case .countdown(_) = stage { return true }
        return false
    }

    private func startAutomaticCaptureSequence() {
        sequenceTask?.cancel()
        sequenceTask = Task {
            // 1. Camera stabilization
            stage = .ready
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }

            // 2. AR Silhouette Guide
            stage = .guiding
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }

            // 3. Countdown 3... 2... 1...
            for i in stride(from: 3, through: 1, by: -1) {
                stage = .countdown(i)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
            }

            // 3b. Micro-anticipation pause
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard !Task.isCancelled else { return }

            // 4. Shutter Flash
            withAnimation(.easeOut(duration: 0.15)) { stage = .flashing }
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }

            // 5. Fire REAL capture
            stage = .capturing
            let correlationId = CorrelationID(rawValue: UUID().uuidString)
            do {
                try await CameraCapabilityService.shared.requestCapture(correlationId: correlationId)
            } catch {
                // Even on capture error, don't crash — surface gracefully
                stage = .reveal
                await onCaptureCompleted("")
                return
            }

            // 6. Reveal — photo is now in CapturedPhotoStore
            stage = .reveal
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            let path = await CapturedPhotoStore.shared.latestCapturedPhotoPath ?? ""
            await onCaptureCompleted(path)
        }
    }
}

#Preview {
    CameraCaptureView(onCaptureCompleted: { _ in })
}
