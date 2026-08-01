// FailureInjector.swift
// HaispaceRuntime — Core/Qualification
//
// Alat untuk mensimulasikan kegagalan hardware & jaringan secara terprogram.
// Digunakan selama M-009 Runtime Qualification untuk menguji Recovery Items.
//
// HANYA AKTIF DI #if DEBUG
// Tidak boleh hadir di production build.

import Foundation

#if DEBUG

@MainActor
public final class FailureInjector {

    public static let shared = FailureInjector()
    private init() {}

    // MARK: - Inject

    public func inject(_ type: FailureInjectionType, into capabilityManager: SystemCapabilityState) async {
        switch type {
        case .cameraUnavailable:
            capabilityManager.updateCamera(status: .error)
            await RuntimeTimelineLogger.shared.logEvent(
                "FAILURE INJECTED",
                payload: "Camera → error (Simulation)"
            )

        case .printerOffline:
            capabilityManager.updatePrinter(status: .unavailable)
            await RuntimeTimelineLogger.shared.logEvent(
                "FAILURE INJECTED",
                payload: "Printer → unavailable (Simulation)"
            )

        case .networkLost:
            capabilityManager.updateNetwork(status: .unavailable)
            await RuntimeTimelineLogger.shared.logEvent(
                "FAILURE INJECTED",
                payload: "Network → unavailable (Simulation)"
            )

        case .restoreAll:
            capabilityManager.updateCamera(status: .available)
            capabilityManager.updatePrinter(status: .unavailable) // printer masih simulated
            capabilityManager.updateNetwork(status: .available)
            await RuntimeTimelineLogger.shared.logEvent(
                "FAILURE RESTORED",
                payload: "All capabilities restored (Simulation)"
            )
        }
    }
}

#endif
