// ScenarioEngine.swift
// HaispaceRuntime — Core/Qualification
//
// Engine untuk menjalankan skenario spesifik QA / Qualification.
// Berfungsi menggantikan injeksi kegagalan mentah menjadi skenario utuh yang mensimulasikan
// konteks di lapangan (misalnya "Kamera putus saat sedang mengambil gambar").
//
// HANYA AKTIF DI #if DEBUG

import Foundation

#if DEBUG

// MARK: - Qualification Scenario Enum

public enum QualificationScenario: String, CaseIterable, Sendable, Identifiable {
    public var id: String { rawValue }

    case printerOffline = "Printer Offline"
    case cameraDisconnectDuringCapture = "Camera Disconnect During Capture"
    case networkLostDuringUpload = "Network Lost During Upload"
    case restoreAll = "Restore All Capabilities"
}

// MARK: - Scenario Engine

@MainActor
public final class ScenarioEngine {

    public static let shared = ScenarioEngine()
    private init() {}

    // MARK: - Run Scenario

    func run(scenario: QualificationScenario, appState: AppState) async {
        let capManager = appState.runtime.capabilityManager

        switch scenario {
        case .printerOffline:
            await RuntimeTimelineLogger.shared.logEvent(
                "SCENARIO STARTED",
                payload: "Printer Offline"
            )
            capManager.updatePrinter(status: .unavailable)
            await RuntimeTimelineLogger.shared.logEvent(
                "SCENARIO ACTION",
                payload: "Printer state forced to .unavailable"
            )

        case .cameraDisconnectDuringCapture:
            await RuntimeTimelineLogger.shared.logEvent(
                "SCENARIO STARTED",
                payload: "Camera Disconnect During Capture"
            )
            // Logika "timing" untuk scenario ini
            // Dalam implementasi nyata, QA menekan ini saat sesi sedang Capture.
            // Kami langsung memutus state kamera.
            capManager.updateCamera(status: .error)
            await RuntimeTimelineLogger.shared.logEvent(
                "SCENARIO ACTION",
                payload: "Camera state forced to .error"
            )

        case .networkLostDuringUpload:
            await RuntimeTimelineLogger.shared.logEvent(
                "SCENARIO STARTED",
                payload: "Network Lost During Upload"
            )
            capManager.updateNetwork(status: .unavailable)
            await RuntimeTimelineLogger.shared.logEvent(
                "SCENARIO ACTION",
                payload: "Network state forced to .unavailable"
            )

        case .restoreAll:
            await RuntimeTimelineLogger.shared.logEvent(
                "SCENARIO ACTION",
                payload: "Restoring all simulated failures"
            )
            capManager.updateCamera(status: .available)
            capManager.updatePrinter(status: .unavailable) // Assume printer needs manual clear if real
            capManager.updateNetwork(status: .available)
        }
    }
}

#endif
