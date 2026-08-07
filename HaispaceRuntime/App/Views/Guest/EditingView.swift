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

    @StateObject private var templateStore = TemplateStore.shared
    
    private let filters: [FilterOption] = [
        FilterOption(id: "original", name: "Original"),
        FilterOption(id: "warm_vibe", name: "Warm Vibe"),
        FilterOption(id: "vintage_bw", name: "B&W Film"),
        FilterOption(id: "soft_glow", name: "Soft Glow")
    ]

    @State private var selectedTemplateId: String = ""
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
            let templates = templateStore.templates
            
            RuntimeTimelineLogger.shared.logEvent("[FORENSIC][TEMPLATE_UI] templatesLoaded: \(templates.count)")
            
            print("[E10_AUDIT] Templates loaded (count: \(templates.count))")
            if let firstTemplate = templates.first {
                self.selectedTemplateId = firstTemplate.id
                
                let store = LocalAssetStore()
                if let asset = store.getAsset(id: firstTemplate.frameAssetId) {
                    let fileURL = asset.fileURL(baseDirectory: store.baseDirectory())
                    let uiImage = UIImage(contentsOfFile: fileURL.path)
                    let decodeSuccess = uiImage != nil
                    
                    RuntimeTimelineLogger.shared.logEvent("[FORENSIC][TEMPLATE_UI] templateId: \(firstTemplate.id)")
                    RuntimeTimelineLogger.shared.logEvent("[FORENSIC][TEMPLATE_UI] templateName: \(firstTemplate.name)")
                    RuntimeTimelineLogger.shared.logEvent("[FORENSIC][TEMPLATE_UI] slotCount: \(firstTemplate.slots.count)")
                    RuntimeTimelineLogger.shared.logEvent("[FORENSIC][TEMPLATE_UI] frameAssetId: \(firstTemplate.frameAssetId)")
                    RuntimeTimelineLogger.shared.logEvent("[FORENSIC][TEMPLATE_UI] frameLocalPath: \(fileURL.path)")
                    RuntimeTimelineLogger.shared.logEvent("[FORENSIC][TEMPLATE_UI] frameUIImageDecode: \(decodeSuccess)")
                    RuntimeTimelineLogger.shared.logEvent("[FORENSIC][TEMPLATE_UI] selectedTemplateId: \(self.selectedTemplateId)")
                } else {
                    RuntimeTimelineLogger.shared.logEvent("[FORENSIC][TEMPLATE_UI] Asset missing for frameAssetId: \(firstTemplate.frameAssetId)")
                }
                
                requestPreviewUpdate()
            } else {
                RuntimeTimelineLogger.shared.logEvent("[FORENSIC][TEMPLATE_UI] Selected Asset: NONE (templates array is empty)")
            }
        }
        .onChange(of: selectedTemplateId) { _, _ in
            requestPreviewUpdate()
        }
        .onChange(of: selectedFilterId) { _, _ in
            requestPreviewUpdate()
        }
    }
    
    private func requestPreviewUpdate() {
        guard !selectedTemplateId.isEmpty else { return }
        let selectedTemplate = templateStore.templates.first(where: { $0.id == selectedTemplateId })
        let frameId = selectedTemplate?.frameAssetId ?? ""
        print("[E10_AUDIT] Preview render requested for template: \(selectedTemplateId), frame: \(frameId), filter: \(selectedFilterId)")
        isLoadingPreview = true
        Task {
            // Tetap pass frameId ke system yang ada agar tidak memecah CoreImageEditingRuntime
            try? await appState.send(.updatePreview(frameId: frameId, filterId: selectedFilterId))
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
            templatesCarousel
        } else {
            filtersCarousel
        }
    }

    private var templatesCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.md) {
                if templateStore.templates.isEmpty {
                    Text("No Templates Available")
                        .font(AppFont.footnote)
                        .foregroundStyle(AppTheme.Brand.textSecondary)
                } else {
                    ForEach(templateStore.templates, id: \.id) { template in
                        templateButton(for: template)
                    }
                }
            }
        }
    }
    
    private func templateButton(for template: TemplateManifest) -> some View {
        Button {
            withAnimation(Motion.screen) { selectedTemplateId = template.id }
        } label: {
            TemplateThumbnailView(frameAssetId: template.frameAssetId)
                .padding(Spacing.xs)
                .background(selectedTemplateId == template.id ? AppTheme.Brand.gold.opacity(0.2) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(selectedTemplateId == template.id ? AppTheme.Brand.gold : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Template \(template.name)")
    }

    private var filtersCarousel: some View {
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

struct TemplateThumbnailView: View {
    let frameAssetId: String
    private let store = LocalAssetStore()
    
    var body: some View {
        VStack(spacing: 4) {
            if let asset = store.getAsset(id: frameAssetId),
               let uiImage = UIImage(contentsOfFile: asset.fileURL(baseDirectory: store.baseDirectory()).path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 60)
                    .overlay(Text("No img").font(.system(size: 8)))
            }
        }
    }
}
