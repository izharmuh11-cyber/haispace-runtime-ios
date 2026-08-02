// LiveEventTimelineView.swift
// HaispaceRuntime — App/Views/Operator
//
// Debug overlay untuk menampilkan workflow event timeline secara live.
// Sesuai dengan "Phase 1: State Machine & Health Contract" untuk memudahkan
// observabilitas tanpa harus membaca log file mentah.

import SwiftUI

struct LiveEventTimelineView: View {
    @Environment(AppState.self) private var appState
    
    // Auto-scroll to bottom
    @Namespace private var bottomID
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "ladybug.fill")
                        .foregroundColor(isExpanded ? .red : .gray)
                    
                    if isExpanded {
                        Text("Timeline (\(activeEvents().count))")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if let sessionId = appState.currentSession?.sessionId {
                            Text(sessionId.prefix(8))
                                .font(.caption2.monospaced())
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(isExpanded ? 0.8 : 0.4))
            }
            .buttonStyle(.plain)
            
            // Content
            if isExpanded {
                ScrollView {
                    ScrollViewReader { proxy in
                        VStack(alignment: .leading, spacing: 6) {
                            let events = activeEvents()
                            
                            if events.isEmpty {
                                Text("Waiting for events...")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .padding()
                            } else {
                                ForEach(events, id: \.id) { event in
                                    EventRowView(event: event)
                                }
                            }
                            
                            // Anchor for auto-scroll
                            Color.clear
                                .frame(height: 1)
                                .id(bottomID)
                        }
                        .padding(12)
                        .onChange(of: activeEvents().count) { _, _ in
                            withAnimation {
                                proxy.scrollTo(bottomID, anchor: .bottom)
                            }
                        }
                    }
                }
                .background(Color.black.opacity(0.6))
            }
        }
        .frame(width: isExpanded ? 320 : nil, height: isExpanded ? 250 : nil)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func activeEvents() -> [RuntimeTimelineEvent] {
        return RuntimeTimelineLogger.shared.events
    }
}

// MARK: - EventRowView

struct EventRowView: View {
    let event: RuntimeTimelineEvent
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Timeline Node
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)
                
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top) {
                    Text(event.type)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(event.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                if let payload = event.payload {
                    Text(payload)
                        .font(.caption2.monospaced())
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
