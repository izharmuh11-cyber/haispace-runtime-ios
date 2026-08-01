// SessionCompletionView.swift
// HaispaceRuntime — App/Views/Guest
//
// Layar penutup sesi — ditampilkan setelah delivery selesai.
// Menampilkan ringkasan sesi dan otomatis kembali ke landing.

import SwiftUI

struct SessionCompletionView: View {
    @Environment(AppState.self) private var appState
    @State private var countdown = 5
    @State private var countdownTask: Task<Void, Never>?
    @State private var appear = false
    
    var body: some View {
        ZStack {
            // Deep dark background
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.05, blue: 0.10), Color(red: 0.02, green: 0.08, blue: 0.15)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Animated success ring
                ZStack {
                    Circle()
                        .stroke(Color.green.opacity(0.15), lineWidth: 3)
                        .frame(width: 180, height: 180)
                    Circle()
                        .stroke(Color.green.opacity(0.4), lineWidth: 2)
                        .frame(width: 150, height: 150)
                        .scaleEffect(appear ? 1.0 : 0.5)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(Color.green)
                        .scaleEffect(appear ? 1.0 : 0.0)
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: appear)
                
                VStack(spacing: 16) {
                    Text("Sesi Selesai!")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("Terima kasih telah menggunakan Haispace.")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: appear)
                
                // Countdown to landing
                VStack(spacing: 8) {
                    Text("Kembali ke layar awal dalam")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                    Text("\(countdown) detik")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .contentTransition(.numericText())
                        .animation(.default, value: countdown)
                }
                .opacity(appear ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.5), value: appear)
                
                Spacer()
                Spacer()
            }
            .padding(40)
        }
        .onAppear {
            appear = true
            RuntimeTimelineLogger.shared.logEvent("SESSION_COMPLETED", payload: "Showing completion screen")
            
            // Start countdown auto-return
            countdownTask = Task {
                for remaining in stride(from: 5, through: 0, by: -1) {
                    await MainActor.run { countdown = remaining }
                    if remaining == 0 {
                        await finishSession()
                        return
                    }
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }
        .onDisappear {
            countdownTask?.cancel()
        }
    }
    
    private func finishSession() async {
        try? await appState.send(.finishSession)
    }
}
