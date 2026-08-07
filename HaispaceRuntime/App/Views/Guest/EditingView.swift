// EditingView.swift
// HaispaceRuntime — App/Views/Customer/Editing
//
// Layar Editing (Quick & Intuitive).
// Refactor: Menggunakan DesignSystem (Tokens, Components, Motion)
// Ref: Lead Apple UI/UX Review (Target 9.9 - 10 / Apple Store Demo Grade)

import SwiftUI

public struct EditingView: View {

    @Environment(AppState.self) private var appState

    public struct FrameOption: Identifiable {
        public let id: String
        public let name: String
        public let colorHex: String
    }

    public struct FilterOption: Identifiable {
        public let id: String
        public let name: String
    }

    @State private var frames: [LocalAsset] = []
    
    private let filters: [FilterOption] = [
        FilterOption(id: "original", name: "Original"),
        FilterOption(id: "warm_vibe", name: "Warm Vibe"),
        FilterOption(id: "vintage_bw", name: "B&W Film"),
        FilterOption(id: "soft_glow", name: "Soft Glow")
    ]

    @State private var selectedFrameId: String = ""
    @State private var selectedFilterId: String = "original"
    @State private var selectedSegment: Int = 0 // 0: Frame, 1: Filter
    @State private var isLoadingPreview: Bool = false

    public var body: some View {
        ZStack {
            AppTheme.Surface.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header (DesignSystem ScreenHeader)
                ScreenHeader(title: "Sentuhan Akhir")
                    .padding(.top, Spacing.section)

                Spacer()

                // Live Preview Area
                previewArea
                    .padding(.horizontal, Spacing.xxl)

                Spacer()

                // Segment Picker (Frame vs Filter)
                segmentPicker
                    .padding(.horizontal, Spacing.xxl)
                    .padding(.bottom, Spacing.lg)

                // Option Selector (Frame colors / Filter list)
                optionsCarousel
                    .frame(height: 70)
                    .padding(.bottom, Spacing.xl)

                // Finish Button (DesignSystem PrimaryButton)
                PrimaryButton(title: "Selesai") {
                    Task { try? await appState.send(.acceptPreview) }
                }
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.section)
            }
        }
        .onAppear {
            print("[E10_AUDIT] EditingView appeared")
            let store = LocalAssetStore()
            self.frames = store.getAllAssets().filter { $0.role.lowercased() == "frame" || $0.assetType.lowercased() == "frame" }
            print("[E10_AUDIT] Frame loaded (count: \(self.frames.count))")
            if let firstFrame = self.frames.first {
                self.selectedFrameId = firstFrame.id
                requestPreviewUpdate()
            }
        }
        .onChange(of: selectedFrameId) { _, _ in
            requestPreviewUpdate()
        }
        .onChange(of: selectedFilterId) { _, _ in
            requestPreviewUpdate()
        }
    }
    
    private func requestPreviewUpdate() {
        guard !selectedFrameId.isEmpty else { return }
        print("[E10_AUDIT] Preview render requested for frame: \(selectedFrameId), filter: \(selectedFilterId)")
        isLoadingPreview = true
        Task {
            try? await appState.send(.updatePreview(frameId: selectedFrameId, filterId: selectedFilterId))
            await MainActor.run { isLoadingPreview = false }
        }
    }

    private var previewArea: some View {
        ZStack {
            if let previewRef = appState.sessionContext.latestPreviewReference,
               let uiImage = UIImage(contentsOfFile: previewRef) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
            } else {
                // Fallback placeholder
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white)
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.5)
                    )
                    .frame(width: 210, height: 360)
                    .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
            }
            
            if isLoadingPreview {
                Color.black.opacity(0.3)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(ProgressView().tint(.white))
            }
        }
    }

    private var segmentPicker: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(Motion.screen) { selectedSegment = 0 }
            } label: {
                Text("Frame")
                    .font(AppFont.footnote)
                    .foregroundStyle(selectedSegment == 0 ? AppTheme.Brand.textPrimary : AppTheme.Brand.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(selectedSegment == 0 ? AppTheme.Brand.textPrimary.opacity(0.15) : Color.clear)
                    .clipShape(Capsule())
            }

            Button {
                withAnimation(Motion.screen) { selectedSegment = 1 }
            } label: {
                Text("Filter")
                    .font(AppFont.footnote)
                    .foregroundStyle(selectedSegment == 1 ? AppTheme.Brand.textPrimary : AppTheme.Brand.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(selectedSegment == 1 ? AppTheme.Brand.textPrimary.opacity(0.15) : Color.clear)
                    .clipShape(Capsule())
            }
        }
        .padding(Spacing.xs)
        .background(AppTheme.Brand.textPrimary.opacity(0.08))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var optionsCarousel: some View {
        if selectedSegment == 0 {
            HStack(spacing: Spacing.md) {
                ForEach(frames, id: \.id) { frame in
                    Button {
                        withAnimation(Motion.screen) { selectedFrameId = frame.id }
                    } label: {
                        Text(frame.name)
                            .font(AppFont.footnote)
                            .foregroundStyle(selectedFrameId == frame.id ? AppTheme.Brand.textDark : AppTheme.Brand.textPrimary)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.sm)
                            .background(selectedFrameId == frame.id ? AppTheme.Brand.textPrimary : AppTheme.Brand.textPrimary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Frame \(frame.name)")
                }
            }
        } else {
            HStack(spacing: Spacing.md) {
                ForEach(filters) { filter in
                    Button {
                        withAnimation(Motion.screen) { selectedFilterId = filter.id }
                    } label: {
                        Text(filter.name)
                            .font(AppFont.footnote)
                            .foregroundStyle(selectedFilterId == filter.id ? AppTheme.Brand.textDark : AppTheme.Brand.textPrimary)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.sm)
                            .background(selectedFilterId == filter.id ? AppTheme.Brand.textPrimary : AppTheme.Brand.textPrimary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Filter \(filter.name)")
                }
            }
        }
    }
}
