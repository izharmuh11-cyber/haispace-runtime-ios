// PhotoSelectionView.swift
// HaispaceRuntime — App/Views/Guest
//
// Layar di mana tamu memilih hasil foto terbaik dari sesi.
//
// M-011 STEP 2: Foto dibaca dari CapturedPhotoStore, bukan SessionStore.photos.
// CapturedPhotoStore adalah satu-satunya sumber kebenaran untuk data foto.
//
// Ref: docs/design/04_ui_design.md — Grid Seleksi Foto

import SwiftUI

struct PhotoSelectionView: View {
    @Environment(AppState.self) private var appState
    
    // M-011 STEP 2: State seleksi dikelola lokal \u2014 akan dipindahkan ke WorkflowOrchestrator di STEP 3
    @State private var selectedPhotoIds: Set<String> = []
    
    // Foto yang difokuskan saat di-tap (popup modal)
    @State private var focusedPhoto: CapturedPhoto?
    
    private var packageLimit: Int {
        appState.currentSession?.package_.minPhotoCount ?? 3
    }
    
    private var photos: [CapturedPhoto] {
        CapturedPhotoStore.shared.capturedPhotos
    }
    
    private var selectedCount: Int { selectedPhotoIds.count }
    private var remaining: Int { packageLimit - selectedCount }
    
    var body: some View {
        ZStack {
            Color(hex: "#080810").ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pilih Foto Terbaikmu")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        if remaining > 0 {
                            Text("Pilih \(remaining) foto lagi")
                                .font(.title3)
                                .foregroundStyle(Color(hex: "#F5A623"))
                        } else {
                            Text("Pemilihan Selesai!")
                                .font(.title3)
                                .foregroundStyle(Color(hex: "#00D9A0"))
                        }
                    }
                    
                    Spacer()
                    
                    // Button Lanjut
                    Button(action: {
                        withAnimation(.spring) {
                            appState.currentSession?.proceedToFrameSelection()
                            appState.navigateTo(.frameSelection)
                        }
                    }) {
                        Text("Lanjut ke Bingkai \u2192")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 32)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(remaining <= 0 ? Color(hex: "#7C5CFC") : Color.white.opacity(0.1))
                            )
                            .shadow(color: remaining <= 0 ? Color(hex: "#7C5CFC").opacity(0.4) : .clear, radius: 10)
                    }
                    .disabled(remaining > 0)
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)
                
                // Grid Foto (Horizontal Scroll, 2 baris)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: [GridItem(.fixed(260), spacing: 20), GridItem(.fixed(260), spacing: 20)], spacing: 20) {
                        // M-011 STEP 2: sumber data = CapturedPhotoStore
                        ForEach(photos) { photo in
                            PhotoGridItem(
                                photo: photo,
                                isSelected: selectedPhotoIds.contains(photo.id)
                            ) {
                                toggleSelection(photoId: photo.id)
                            } onLongPress: {
                                withAnimation(.spring) {
                                    focusedPhoto = photo
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                }
                .frame(maxHeight: 560)
                
                Spacer()
                
                // Indikator P2P Transfer Status
                if photos.contains(where: { !$0.isFullQuality }) {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("Mentransfer foto resolusi tinggi...")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.bottom, 20)
                    .transition(.opacity)
                }
            }
            
            // Popup Focus View
            if let photo = focusedPhoto {
                ZStack {
                    Color.black.opacity(0.85).ignoresSafeArea()
                        .blur(radius: 20)
                        .onTapGesture {
                            withAnimation(.spring) {
                                focusedPhoto = nil
                            }
                        }
                    
                    if let image = photo.displayImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(24)
                            .padding(60)
                            .shadow(radius: 30)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        ProgressView()
                            .tint(.white)
                    }
                    
                    // Close Button
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(.spring) {
                                    focusedPhoto = nil
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .padding(40)
                            }
                        }
                        Spacer()
                    }
                }
                .zIndex(100)
            }
        }
    }
    
    // MARK: - Selection Logic (lokal sementara \u2014 STEP 3 akan pindahkan ke WorkflowOrchestrator)
    
    private func toggleSelection(photoId: String) {
        if selectedPhotoIds.contains(photoId) {
            selectedPhotoIds.remove(photoId)
        } else if selectedPhotoIds.count < packageLimit {
            selectedPhotoIds.insert(photoId)
        }
    }
}

// MARK: - Photo Grid Item

private struct PhotoGridItem: View {
    let photo: CapturedPhoto
    let isSelected: Bool
    let action: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                // Gambar
                if let image = photo.thumbnailImage {
                    let aspect = image.size.width / image.size.height
                    let cardHeight: CGFloat = 260
                    let cardWidth = cardHeight * aspect
                    
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipped()
                        .cornerRadius(16)
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 346, height: 260)
                        .cornerRadius(16)
                        .overlay(ProgressView().tint(.white))
                }
                
                // Selection Indicator
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(hex: "#00D9A0") : Color.black.opacity(0.4))
                        .frame(width: 32, height: 32)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "circle")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(12)
                
                // Resolution Quality Indicator
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        if photo.isFullQuality {
                            Image(systemName: "hq")
                                .font(.caption2)
                                .foregroundStyle(Color.green)
                                .padding(4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(4)
                                .padding(8)
                        } else {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.white)
                                .padding(4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(4)
                                .padding(8)
                        }
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? LinearGradient(colors: [Color(hex: "#00D9A0"), Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: isSelected ? 4 : 1)
            )
            .scaleEffect(isSelected ? 0.96 : 1.0)
            .rotation3DEffect(
                .degrees(isSelected ? -4 : 0),
                axis: (x: 0.1, y: 1.0, z: 0.0)
            )
            .shadow(color: isSelected ? Color(hex: "#00D9A0").opacity(0.55) : Color.black.opacity(0.45), radius: isSelected ? 20 : 10, y: isSelected ? 12 : 5)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                onLongPress()
            }
        )
    }
}

#Preview {
    PhotoSelectionView()
        .environment(AppState.previewWithActiveSession)
}
