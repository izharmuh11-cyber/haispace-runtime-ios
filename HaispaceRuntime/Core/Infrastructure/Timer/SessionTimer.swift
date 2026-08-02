// SessionTimer.swift
// HaispaceRuntime — Core/Infrastructure/Timer
//
// M-011.5: Runtime Timer Infrastructure
//
// PRINSIP:
//   Timer ini tidak mengetahui domain apapun:
//   - Tidak tahu Camera
//   - Tidak tahu Session
//   - Tidak tahu Payment
//   - Tidak tahu Package
//   - Tidak tahu Guest
//
//   Dia hanya menghitung waktu dan memancarkan event.
//   Semua keputusan bisnis berdasarkan event ada di WorkflowOrchestrator.
//
// PENGGUNAAN:
//   WorkflowOrchestrator.startPhotoSessionTimer(duration: 300)
//   WorkflowOrchestrator menerima TimerEvent dan memutuskan respons.
//
// FUTURE USE (tanpa mengubah Timer ini):
//   - Payment Timeout
//   - Pairing Timeout
//   - Printer Timeout
//   - Cloud Retry Backoff

import Foundation

// MARK: - TimerEvent

/// Event yang dipancarkan SessionTimer.
/// Consumer (WorkflowOrchestrator) memutuskan apa yang dilakukan.
enum TimerEvent: Sendable {
    /// Setiap detik berlalu. `remaining` = detik yang tersisa.
    case tick(remaining: Int)
    /// Timer mencapai nol.
    case finished
    /// Timer dijeda oleh operator.
    case paused(remainingAtPause: Int)
    /// Timer dilanjutkan setelah pause.
    case resumed(remaining: Int)
}

// MARK: - SessionTimer

/// Timer sederhana yang menghasilkan AsyncStream<TimerEvent>.
///
/// Timer ini bodoh secara sengaja.
/// Ia tidak tahu apa yang sedang dihitung — hanya berapa detik yang tersisa.
///
/// Contoh penggunaan:
/// ```swift
/// let timer = SessionTimer()
/// for await event in timer.start(duration: 300) {
///     switch event {
///     case .tick(let remaining): updateUI(remaining)
///     case .finished: orchestrator.handleSessionTimeout()
///     case .paused: orchestrator.handlePause()
///     case .resumed: orchestrator.handleResume()
///     }
/// }
/// ```
final class SessionTimer: @unchecked Sendable {
    
    // MARK: - State
    
    private var remainingSeconds: Int = 0
    private var isPaused: Bool = false
    private var isStopped: Bool = false
    
    // MARK: - Control
    
    private var pauseContinuation: CheckedContinuation<Void, Never>?
    private let lock = NSLock()
    
    // MARK: - Public Interface
    
    /// Mulai timer dengan durasi tertentu.
    /// Memancarkan `.tick` setiap detik, `.finished` saat habis.
    /// Kembalikan AsyncStream yang bisa di-iterate oleh WorkflowOrchestrator.
    func start(duration: Int) -> AsyncStream<TimerEvent> {
        lock.withLock {
            remainingSeconds = duration
            isPaused = false
            isStopped = false
        }
        
        return AsyncStream { continuation in
            Task {
                var remaining = duration
                
                while remaining >= 0 {
                    let stopped = lock.withLock { isStopped }
                    if stopped { break }
                    
                    // Jika di-pause, tunggu resume
                    let paused = lock.withLock { isPaused }
                    if paused {
                        continuation.yield(.paused(remainingAtPause: remaining))
                        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                            lock.withLock { pauseContinuation = c }
                        }
                        let stillStopped = lock.withLock { isStopped }
                        if stillStopped { break }
                        continuation.yield(.resumed(remaining: remaining))
                        continue
                    }
                    
                    // Emit tick
                    continuation.yield(.tick(remaining: remaining))
                    
                    if remaining == 0 {
                        continuation.yield(.finished)
                        break
                    }
                    
                    // Tunggu 1 detik
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    remaining -= 1
                    lock.withLock { remainingSeconds = remaining }
                }
                
                continuation.finish()
            }
        }
    }
    
    /// Pause timer. Timer berhenti di detik saat ini.
    func pause() {
        lock.withLock { isPaused = true }
    }
    
    /// Resume timer dari posisi pause.
    func resume() {
        lock.withLock {
            isPaused = false
            pauseContinuation?.resume()
            pauseContinuation = nil
        }
    }
    
    /// Stop timer sepenuhnya. Stream selesai.
    func stop() {
        lock.withLock {
            isStopped = true
            isPaused = false
            pauseContinuation?.resume()
            pauseContinuation = nil
        }
    }
    
    /// Sisa detik saat ini (thread-safe read).
    var currentRemaining: Int {
        lock.withLock { remainingSeconds }
    }
}
