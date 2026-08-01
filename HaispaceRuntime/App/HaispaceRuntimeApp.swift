// HaispaceRuntimeApp.swift
// HaispaceRuntime — App
//
// Official Entry Point — haispace-runtime-ios
//
// Born from: M-003 — Repository Initialization
// Signed:    M-002 — Product Archaeology Closure (2026-08-01)
//
// Architecture Ref: haispace-platform/constitution/PLATFORM_RUNTIME_V1.md
// ADR Ref:          haispace-platform/adr/ADR-011-platform-runtime-freeze.md
//
// ASSEMBLY ORDER (Platform Runtime v1.0):
//   1. RuntimeContainer.build(.production) → assembles all Modules
//   2. AppState(runtime: container)        → thin SwiftUI bridge
//   3. .environment(appState)              → inject into entire view hierarchy
//
// AppState does NOT create any dependencies.
// RuntimeContainer is the one and only Composition Root.

import SwiftUI
import BackgroundTasks
import UIKit

// MARK: - App Entry Point

@main
struct HaispaceRuntimeApp: App {

    // MARK: State
    @State private var appState: AppState = {
        let container: RuntimeContainer
        do {
            container = try RuntimeContainer.build(for: .production)
        } catch {
            HaispaceLogger.warning(
                "RuntimeContainer.build(.production) failed: \(error.localizedDescription) — falling back to .development",
                category: "runtime"
            )
            container = (try? RuntimeContainer.build(for: .development)) ?? {
                fatalError("RuntimeContainer: cannot build even for .development — check environment configuration.")
            }()
        }
        return AppState(runtime: container)
    }()

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .onAppear {
                    AppDelegate.appState = appState
                }
                .task {
                    await appState.setup()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    appState.handleAppBecomeActive()
                }
        }
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, UIApplicationDelegate {

    static weak var appState: AppState?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        setupBackgroundTasks()
        setupAppearance()
        UIDevice.current.isBatteryMonitoringEnabled = true
        return true
    }

    private func setupBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "id.haispaceproject.runtime.license-check",
            using: nil
        ) { task in
            task.expirationHandler = {
                task.setTaskCompleted(success: false)
                HaispaceLogger.warning("BGTask expired: license-check", category: "bg")
            }
            Task {
                await AppDelegate.appState?.license.performHeartbeat()
                task.setTaskCompleted(success: true)
                self.scheduleLicenseCheckTask()
            }
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "id.haispaceproject.runtime.photo-upload",
            using: nil
        ) { task in
            task.expirationHandler = {
                task.setTaskCompleted(success: false)
            }
            Task {
                // TODO: M-005 — CloudUploadService background session
                task.setTaskCompleted(success: true)
            }
        }

        scheduleLicenseCheckTask()
    }

    func scheduleLicenseCheckTask() {
        let request = BGProcessingTaskRequest(identifier: "id.haispaceproject.runtime.license-check")
        request.requiresNetworkConnectivity = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: 7 * 24 * 3600)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            HaispaceLogger.warning("BGTask schedule failed: \(error.localizedDescription)", category: "bg")
        }
    }

    private func setupAppearance() {
        UIApplication.shared.isIdleTimerDisabled = true

        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "dev"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        HaispaceLogger.info(
            "HaiBooth Runtime launched — build: #\(build) (\(version)) — device: \(UIDevice.current.model)",
            category: "app"
        )
    }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        // TODO: M-005 — CloudUploadService background session handler
        HaispaceLogger.info("Background URL session event: \(identifier)", category: "upload")
        completionHandler()
    }
}
