// BootstrapLoadingView.swift
// HaispaceRuntime — App/Views/Support

import SwiftUI

struct BootstrapLoadingView: View {
    let currentState: BootstrapState
    
    // Obervasi logger agar UI terupdate saat log bertambah
    @State private var logger = BootstrapObservabilityLogger.shared
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 20) {
                
                HStack {
                    Image(systemName: "terminal")
                        .font(.title2)
                        .foregroundColor(.green)
                    Text("HAISPACE PLATFORM AWAKENING")
                        .font(.headline)
                        .foregroundColor(.green)
                        .bold()
                }
                .padding(.bottom, 20)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(logger.timeline, id: \.self) { log in
                            Text(log)
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundColor(.green.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .defaultScrollAnchor(.bottom) // Auto-scroll ke paling bawah
                
                HStack {
                    ProgressView()
                        .tint(.green)
                        .padding(.trailing, 8)
                    Text("Current Phase: \(currentState.rawValue.uppercased())")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.green)
                }
                .padding(.top, 20)
            }
            .padding(40)
            
            // Vignette effect for retro terminal feel
            RadialGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.6)]), center: .center, startRadius: 100, endRadius: 600)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}
