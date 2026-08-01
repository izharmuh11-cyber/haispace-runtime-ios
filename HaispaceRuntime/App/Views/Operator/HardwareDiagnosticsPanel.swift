// HardwareDiagnosticsPanel.swift
// HaispaceRuntime — App/Views/Operator

import SwiftUI

struct HardwareDiagnosticsPanel: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    @State private var isPrinterTesting = false
    @State private var isCameraTesting = false
    @State private var capturedPhotoPath: String?
    
    var body: some View {
        NavigationStack {
            List {
                Section("Platform Overview") {
                    HStack {
                        Text("App State")
                        Spacer()
                        Text(appState.isAppReady ? "Ready" : "Loading")
                            .foregroundColor(appState.isAppReady ? .green : .orange)
                    }
                }
                
                Section("Capability Health") {
                    healthRow(name: "Network", status: appState.runtime.capabilityManager.state.network)
                    healthRow(name: "Camera", status: appState.runtime.capabilityManager.state.camera)
                    healthRow(name: "Printer", status: appState.runtime.capabilityManager.state.printer)
                    // Note: Storage & P2P can be added here
                }
                
                Section("Hardware Actions") {
                    Button(action: testCamera) {
                        HStack {
                            Text("Test Camera Capture")
                            Spacer()
                            if isCameraTesting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isCameraTesting || appState.runtime.capabilityManager.state.camera != .available)
                    
                    if let path = capturedPhotoPath {
                        Text("Saved to: \(path)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: testPrinter) {
                        HStack {
                            Text("Send Test Print Page")
                            Spacer()
                            if isPrinterTesting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isPrinterTesting || appState.runtime.capabilityManager.state.printer != .available)
                    
                    Button("Trigger P2P Advertising (Experimental)") {
                        Task {
                            try? await P2PCapabilityService.shared.prepare(configuration: .init())
                        }
                    }
                }
            }
            .navigationTitle("Hardware Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                // Initialize Printer Discovery on Panel Open
                Task {
                    _ = try? await PrinterCapabilityService.shared.detectPrinter()
                }
                // Initialize Camera internally if not yet prepared
                Task {
                    let cameraSvc = CameraCapabilityService.shared
                    let health = await cameraSvc.healthSnapshot
                    if health.status != .ready {
                        try? await cameraSvc.prepare(configuration: .init())
                        await MainActor.run {
                            appState.runtime.capabilityManager.updateCamera(status: .available)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func healthRow(name: String, status: CapabilityStatus) -> some View {
        HStack {
            Text(name)
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(colorForStatus(status))
                    .frame(width: 8, height: 8)
                Text(status.rawValue.uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func colorForStatus(_ status: CapabilityStatus) -> Color {
        switch status {
        case .available: return .green
        case .degraded: return .yellow
        case .unavailable: return .red
        case .error: return .red
        case .unknown: return .gray
        }
    }
    
    private func testPrinter() {
        isPrinterTesting = true
        Task {
            try? await appState.runtime.orchestrator.handleIntent(.testPrinter)
            await MainActor.run { isPrinterTesting = false }
        }
    }
    
    private func testCamera() {
        isCameraTesting = true
        Task {
            try? await appState.runtime.orchestrator.handleIntent(.testCameraCapture)
            await MainActor.run { isCameraTesting = false }
        }
    }
}
