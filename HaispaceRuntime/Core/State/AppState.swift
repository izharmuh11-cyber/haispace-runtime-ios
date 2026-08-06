// AppState.swift
// HaispaceRuntime — Core/State
//
// Root Observable — di-inject ke seluruh app via .environment.
//
// TANGGUNG JAWAB (tepat tiga — tidak boleh lebih):
//   1. UI Navigation  — currentRoute, KioskRoute
//   2. App Lifecycle  — setup(), handleAppBecomeActive()
//   3. Runtime Bridge — meneruskan intent ke RuntimeContainer.orchestrator
//
// YANG TIDAK BOLEH ADA DI SINI (GPT Architecture Review):
//   - Business logic (itu urusan Session Aggregate)
//   - Dependency creation (itu urusan RuntimeContainer)
//   - PaymentStore, SessionStore, DeliveryStore, PhotoStore reference
//   - Keputusan tentang "apakah payment valid" atau "berapa foto yang boleh dipilih"
//
// AppState hanya meneruskan intent dan memantulkan state.
//
// Ref: haispace-platform/constitution/PLATFORM_RUNTIME_V1.md
// Ref: haispace-platform/adr/ADR-011-platform-runtime-freeze.md

import Foundation
import Observation
import UIKit

// MARK: - AppState

@Observable
@MainActor
final class AppState {

    // MARK: - Runtime (single source of truth)

    /// RuntimeContainer adalah satu-satunya komponen yang AppState ketahui.
    /// AppState tidak pernah menyentuh dependency di dalam container secara langsung.
    let runtime: RuntimeContainer

    // MARK: - Non-Runtime Stores (belum dimigrasikan ke Runtime)
    //
    // CATATAN MIGRASI:
    //   Auth, License, P2P, BoothConfig, OperatorState bukan bagian dari Session Aggregate.
    //   Mereka adalah platform-level state yang saat ini masih di-hold oleh AppState.
    //   PR-13 (Session Root) akan menentukan apakah ini perlu masuk ke RuntimeModule baru.
    //
    let auth = AuthStore()
    let license = LicenseStore()
    let p2p = P2PStore()
    let boothConfig = BoothConfigStore()
    let operatorState = OperatorStore()



    // MARK: - Pending Guest (UI-level transient state)

    /// Tamu yang sedang registrasi tapi belum memilih paket.
    /// Ini adalah UI transient state — bukan Session state.
    var pendingGuest: GuestInfo?

    // MARK: - App-Level State

    var isAppReady: Bool = false
    var isOnline: Bool = false
    var isKioskModeActive: Bool = false

    /// Orphaned sessions yang ditemukan saat launch — ditangani oleh Recovery Engine (Phase C).
    var orphanedSessionDecisions: [OrphanedSessionDecision] = []
    
    // MARK: - Session Context (M-011 STEP 3B.1)
    // Snapshot ringan dari HaispaceSession.activeSession untuk konsumsi View.
    // View tidak boleh menyentuh SessionStore atau WorkflowOrchestrator secara langsung.
    // Di-refresh otomatis setiap kali send() dipanggil.
    struct SessionContext {
        let maxPhotoCount: Int
        let minPhotoCount: Int
        let queueNumber: Int
        let guestName: String
        /// M-011.5: Countdown detik dari SessionTimer via WorkflowOrchestrator
        let remainingSeconds: Int
        /// Output path dari pratinjau rendering terakhir
        let latestPreviewReference: String?
        
        static let empty = SessionContext(maxPhotoCount: 10, minPhotoCount: 3, queueNumber: 1, guestName: "Guest", remainingSeconds: 0, latestPreviewReference: nil)
    }
    
    /// Snapshot context session aktif — dibaca oleh View untuk package dan guest info.
    private(set) var sessionContext: SessionContext = .empty

    // MARK: - Computed

    var isBoothReady: Bool {
        p2p.isConnected &&
        license.isValid &&
        boothConfig.isConfigured
    }

    var isOperatorActive: Bool {
        auth.isLoggedIn && operatorState.isOperatorActive
    }

    // MARK: - Navigation State (tanggung jawab 1 dari 3)

    enum KioskRoute: Hashable {
        case landing
        case guestRegistration
        case packageSelection
        case activeSession
        case photoSelection
        case frameSelection
        case payment
        case processing
        case delivery
        case sessionComplete
    }

    /// Route saat ini untuk SwiftUI View — di-sync dari WorkflowOrchestrator via send().
    /// TIDAK boleh di-set langsung dari View. Gunakan send(_ intent:).
    private(set) var currentRoute: KioskRoute = .landing

    // MARK: - Initializer (tanggung jawab 2 dari 3)

    /// AppState menerima RuntimeContainer dari luar — tidak pernah membuatnya sendiri.
    /// Di-inject dari HaispaceRuntimeApp setelah RuntimeContainer.build() selesai.
    init(runtime: RuntimeContainer) {
        self.runtime = runtime
    }

    // MARK: - Intent Dispatch (tanggung jawab 3 dari 3)

    /// Satu-satunya cara yang benar untuk mengubah workflow dari View.
    /// AppState meneruskan ke Runtime — tidak membuat keputusan sendiri.
    func send(_ intent: WorkflowIntent) async throws {
        // M-011 FINAL: Compatibility bridge ke SessionStore dihapus.
        // WorkflowOrchestrator adalah satu-satunya yang memproses intent.
        try await runtime.orchestrator.handleIntent(intent)
        let newStage = await runtime.orchestrator.currentStage
        let newRoute = WorkflowRouteMapper.route(for: newStage)
        if currentRoute != newRoute {
            currentRoute = newRoute
            print("[E10_AUDIT] Router -> \(newRoute)")
            
            // M-011 FIX: Otomatis upload log ke R2 saat terjadi transisi UI penting
            // Ini membantu debug automation test agar kita selalu punya log terakhir di R2.
            R2LogUploader.uploadLatestLog(eventName: "route_\(newRoute)")
        }
        // M-011 STEP 3B.1: Refresh SessionContext dari HaispaceSession actor setiap kali intent diproses
        if let activeSession = await runtime.orchestrator.activeSession {
            let policy = await activeSession.capturePolicy
            let guest = await activeSession.identity.guest
            let remaining = await runtime.orchestrator.sessionTimerRemaining
            let previewRef = await runtime.orchestrator.activePreviewReference
            sessionContext = SessionContext(
                maxPhotoCount: policy.maxCount,
                minPhotoCount: policy.minSelectionCount,
                queueNumber: guest.queueNumber,
                guestName: guest.name,
                remainingSeconds: remaining,
                latestPreviewReference: previewRef
            )
        }

        // Flush domain events ke Publisher setelah setiap intent
        await runtime.flushSessionEvents()
    }

    // MARK: - App Lifecycle (tanggung jawab 2 dari 3)

    /// Setup awal saat app launch — validasi license, restore session, launch recovery.
    func setup() async {
        HaispaceLogger.info("AppState setup dimulai", category: "app")

        // 0. Mulai background observer untuk Runtime (M-011.5 Timer & Auto-Transitions)
        startRuntimeObserver()

        // 0. M-005: Platform Awakening — Runtime Bootstrap
        await runtime.bootstrapEngine.startBootstrapSequence()

        // 1. Runtime launch recovery — cek apakah ada session in-progress di disk
        await runtime.performLaunchRecovery()

        // 1. Orphaned session detection (Legacy — akan digantikan Recovery Engine Phase C)
        let orphans = OrphanedSessionDetector.detect()
        if !orphans.isEmpty {
            HaispaceLogger.warning(
                "AppState: \(orphans.count) orphaned session(s) — pending Phase C Recovery Engine",
                category: "app"
            )
            orphanedSessionDecisions = orphans
        }

        // 2. Validasi lisensi
        await license.validateOnLaunch()

        // 3. Restore auth session dari Keychain
        await auth.restoreSession()

        // 4. Load booth config dari lokal
        await boothConfig.loadFromLocal()

        #if DEBUG
        HaispaceLogger.warning("⚠️ DEBUG MODE: License & config di-override dengan mock data", category: "app")
        license.status = .valid
        boothConfig.activeEventId = "event-test-001"
        boothConfig.activeEventName = "Test Event"
        boothConfig.activePackages = BoothPackage.mockPackages
        #endif

        // 5. Housekeeping
        SessionAuditTrail.purgeOldCompleted(olderThan: 30)

        isAppReady = true
        HaispaceLogger.info(
            "AppState setup selesai — boothReady: \(isBoothReady) — runtime: \(RuntimeDescriptor.current.runtimeId)",
            category: "app"
        )
    }

    /// App menjadi aktif (dari background) — validasi lisensi jika diperlukan.
    func handleAppBecomeActive() {
        Task {
            await license.validateIfNeeded()
        }
    }

    // MARK: - Navigation Helper
    // M-011 FINAL: navigateTo hanya mengubah route — tidak lagi membuat SessionStore.
    // Semua workflow state dikelola oleh WorkflowOrchestrator.
    func navigateTo(_ route: KioskRoute) {
        currentRoute = route
        HaispaceLogger.info("[Route] \(route)", category: "workflow")
    }
    
    // MARK: - Runtime Background Observer (M-011.5)
    
    private var runtimeObserverTask: Task<Void, Never>?
    
    /// Mengawasi perubahan state asinkron dari WorkflowOrchestrator
    /// (misal: Timer habis, Kuota Foto penuh, atau Push Event Cloud).
    private func startRuntimeObserver() {
        runtimeObserverTask?.cancel()
        runtimeObserverTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000) // Poll 0.5s
                guard let self else { break }
                
                let stage = await self.runtime.orchestrator.currentStage
                let remaining = await self.runtime.orchestrator.sessionTimerRemaining
                
                // 1. Sync Route (Auto-transition)
                let newRoute = WorkflowRouteMapper.route(for: stage)
                if newRoute != self.currentRoute && newRoute != .landing {
                    // Hanya otomatis update jika berbeda dan bukan sedang reset ke landing secara paksa
                    self.currentRoute = newRoute
                    print("[E10_AUDIT] Auto-Transition -> \(newRoute)")
                    R2LogUploader.uploadLatestLog(eventName: "auto_route_\(newRoute)")
                }
                
                // 2. Sync SessionContext Timer
                if self.sessionContext.remainingSeconds != remaining {
                    self.sessionContext = SessionContext(
                        maxPhotoCount: self.sessionContext.maxPhotoCount,
                        minPhotoCount: self.sessionContext.minPhotoCount,
                        queueNumber: self.sessionContext.queueNumber,
                        guestName: self.sessionContext.guestName,
                        remainingSeconds: remaining,
                        latestPreviewReference: self.sessionContext.latestPreviewReference
                    )
                }
            }
        }
    }
    
    // M-011 FINAL: hasActiveSession sekarang berdasarkan WorkflowOrchestrator.currentStage
    var hasActiveSession: Bool {
        let activeStages: [KioskRoute] = [.activeSession, .photoSelection, .frameSelection, .payment, .processing, .delivery]
        return activeStages.contains(currentRoute)
    }
}

// MARK: - AppState Preview Mock

extension AppState {

    @MainActor
    static var preview: AppState {
        let runtime = try! RuntimeContainer.build(for: .development)
        let state = AppState(runtime: runtime)

        #if DEBUG
        state.auth.currentUser = .mockOperator
        state.auth.authStatus = .authenticated
        state.license.status = .valid
        state.license.expiresAt = Date().addingTimeInterval(30 * 24 * 3600)
        state.p2p.connectionState = .connected
        state.p2p.latencyMs = 12
        state.p2p.connectedPeerName = "iPhone 14 Haispace"
        #endif
        state.p2p.connectedPeerBatteryLevel = 0.85
        state.boothConfig.activeEventId = "event-preview-001"
        state.boothConfig.activeEventName = "Wisuda BINUS 2026"
        state.boothConfig.activeEventVenue = "Jakarta Convention Center"
        state.boothConfig.activeEventDate = Date()
        state.boothConfig.activePackages = BoothPackage.mockPackages
        state.boothConfig.availableFrames = PhotoFrame.mockFrames
        state.boothConfig.downloadedFrameIds = Set(PhotoFrame.mockFrames.map { $0.id })
        state.operatorState.currentOperator = .mockOperator

        return state
    }

    @MainActor
    static var previewWithActiveSession: AppState {
        let state = preview
        // M-011 FINAL: Preview menggunakan CapturedPhotoStore langsung, tanpa SessionStore
        state.currentRoute = .activeSession
        state.sessionContext = SessionContext(
            maxPhotoCount: 5,
            minPhotoCount: 3,
            queueNumber: 42,
            guestName: "Sarah",
            remainingSeconds: 180,
            latestPreviewReference: nil
        )
        let mockPhotos = CapturedPhoto.mockPhotos(count: 5)
        for photo in mockPhotos {
            CapturedPhotoStore.shared.receivePhotoEvent(.thumbnailArrived(
                photoId: photo.id,
                data: photo.thumbnailData,
                capturedAt: photo.capturedAt,
                sortOrder: photo.sortOrder
            ))
        }
        return state
    }
}


