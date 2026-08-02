# Haispace Platform — Master Roadmap
**Terakhir diperbarui: 2026-08-02 | Oleh: Chief Product Architect + Antigravity**

---

> ## Insight Arsitektural Terbaru
>
> Setelah product archaeology terhadap legacy web photobooth, kami menyadari bahwa Haispace sebenarnya terdiri dari **dua produk yang berbeda**:
>
> | Produk | Deskripsi | Target User |
> |---|---|---|
> | **Runtime Platform** | Berjalan di booth (iPad). Camera → Workflow → Frame → Print → Cloud | Tamu photobooth |
> | **Authoring Platform** | Dipakai tim desain untuk membuat frame. PNG → Auto-detect → Preview → Publish | Tim desain |
>
> Dulu keduanya bercampur di project web lama. Sekarang kita pisahkan dengan arsitektur yang lebih bersih.

---

## ✅ M-010 — Native Camera Foundation
**Status: SELESAI & FROZEN**

Pipeline kamera native iPad berdiri solid. File-file berikut masuk **Platform Freeze v1.0**:
- `CameraSessionController.swift`
- `CapturePipeline.swift`
- `CameraPreviewLayerView.swift`
- `CameraOrientationCoordinator.swift`

---

## ✅ M-011 — Single Runtime Workflow
**Status: SELESAI**

`SessionStore` dihapus. Zero bridge. Zero legacy. Semua state mengalir melalui `WorkflowOrchestrator`.

Commit closure: `0f1dca1`

---

## 🔄 M-012 — Frame Engine (Runtime Platform)
**Status: Engineering Complete — Waiting for Production Frame Assets & Device Validation**

**Definition of Done (12 kriteria):**

| # | Kriteria | Status |
|---|---|---|
| 1 | Arsitektur Editing stabil (zero hidden dependency) | ✅ |
| 2 | Runtime tidak tahu domain (Session, Guest, Package) | ✅ |
| 3 | `RenderedOutput` rich model — dipakai semua consumer | ✅ |
| 4 | `PhotoReference` value type — tidak lempar singleton | ✅ |
| 5 | `outputDirectory` di-inject dari luar | ✅ |
| 6 | Platform Baseline v1.0 tidak dilanggar | ✅ |
| 7 | Validator lulus 7/7 checks | ⏳ iPad |
| 8 | 3 template (Single, Strip, Quad) render tanpa kode baru | ⏳ iPad |
| 9 | Preview ↔ Export aspect ratio konsisten | ⏳ iPad |
| 10 | Benchmark performa dalam target (< 2000ms) | ⏳ iPad |
| 11 | **Hasil render dilihat visual oleh manusia di iPad** | ❌ |
| 12 | Log diagnostik tersimpan di R2 | ❌ |

**Post-M-012 Improvement (dijadwalkan setelah closure):**
- PNG LRU Cache di `CoreImageEditingRuntime` — menghindari re-read disk setiap render (pola dari legacy `pngCache` Map max-50)

---

## 📋 M-012A — Frame Authoring Platform
**Status: PLANNED — mulai setelah M-012 ditutup**

**Konteks:**
Archaeology legacy project menemukan bahwa sistem lama punya **Frame Authoring System** yang lebih canggih dari yang diingat — BFS+PCA auto-detection slot, visual drag-drop editor, chroma key removal. Ini adalah Intellectual Property yang berharga.

**Keputusan Chief:** Pisahkan dari M-012. Frame Authoring adalah **produk yang berbeda** dari Frame Engine.

**Target user: Tim Desain** (bukan tamu booth)

**Pipeline yang dibangun:**
```
Designer
    │
    ▼ Upload PNG dengan area transparan (alpha=0)
FrameSlotDetector
    │   Scan pixel, BFS cluster, PCA rotation
    │   Auto-generate slot coordinates
    ▼
.template.json
    │   { slots: [{x, y, width, height, rotation}], canvasWidth, canvasHeight }
    ▼
Visual Preview (SwiftUI atau Mac app)
    │   Overlay slot highlight di atas PNG
    │   Fine-tune drag-and-drop
    ▼
Publish
    │   PNG + template.json siap
    │   Upload ke CDN: cdn.haispace.id/frames/{eventSlug}/
    ▼
Native App download otomatis
```

**Prinsip utama:**
> "Designer cukup membuat PNG transparan. Selesai. Sisanya pekerjaan sistem."

**Eliminasi:**
- ❌ `FRAME_ASSET_SPEC.md` dengan tabel koordinat piksel manual
- ❌ Koordinasi angka antara desainer dan engineer
- ❌ Perubahan kode setiap ada frame baru

**File yang akan dibuat (planning):**
- `FrameSlotDetector.swift` — BFS scan alpha=0, output `[TemplateSlot]`
- `FrameAuthoringService.swift` — orchestrator authoring workflow
- `FrameTemplateWriter.swift` — generate + simpan `.template.json`
- Authoring UI (platform TBD: iPad app, Mac app, atau web tool)

**Tanda selesai:**
Desainer upload `frame-wedding.png` → sistem otomatis generate `frame-wedding.template.json` → Frame Engine langsung bisa render tanpa perubahan kode.

---

## M-013 — Filter / Editing Experience
**Status: PLANNED**

LUT Metal filter di atas `RenderedOutput`. Tamu bisa memilih filter sebelum print.

```
RenderedOutput
    ↓
LUT Filter (Metal)
    ↓
FilteredOutput
    ↓
Payment → Print
```

---

## M-014 — Print Experience (Printer Platform)
**Status: PLANNED**

`PrinterValidator` mulai diisi implementasi. `RenderedOutput.fullPath` → AirPrint / DNP thermal printer.

```
RenderedOutput
    ↓
PrinterCapability
    ↓
AirPrint / DNP SDK
```

---

## M-015 — Cloud Delivery
**Status: PLANNED**

`CloudValidator` mulai diisi. `RenderedOutput` → R2 Cloudflare upload → QR code untuk tamu.

```
RenderedOutput
    ↓
CloudCapability
    ↓
R2 Upload → CDN URL
    ↓
QR Code → Tamu scan → Download foto
```

---

## M-016 — iPhone Camera Node (P2P)
**Status: PLANNED**

iPhone sebagai kamera eksternal via P2P. Foto mengalir ke `CapturedPhotoStore` dengan interface yang sama dengan kamera iPad.

```
iPhone (kamera)
    ↓
P2P Channel
    ↓
CapturedPhotoStore
    ↓
[workflow tidak berubah]
```

---

## M-017 — Runtime Certification
**Status: PLANNED (setelah M-014 + M-015)**

Full end-to-end certification run. Semua capability lulus `PlatformDiagnosticsService.runAll()`.

```
Hardware Camera
    ↓
Workflow Engine
    ↓
Frame Compositor (M-012)
    ↓
Filter Engine (M-013)
    ↓
Printer (M-014)
    ↓
Cloud (M-015)
    ↓
✅ Haispace Runtime Platform v1.0 Certified
```

---

## Catatan Arsitektural

> *"Mulai setelah ini, setiap milestone akan semakin terasa sebagai pembangunan **produk**, bukan lagi pembuktian **arsitektur**."*
>
> — Chief Product Architect, setelah M-011

> *"Haispace sekarang terbagi menjadi dua produk yang berbeda: Runtime Platform dan Authoring Platform. Dulu keduanya bercampur. Sekarang kita punya kesempatan memisahkannya dengan arsitektur yang jauh lebih bersih."*
>
> — Chief Product Architect, setelah Product Archaeology M-012

---

## Platform Baseline v1.0 — Frozen Components

File-file berikut **tidak boleh dimodifikasi** kecuali ada bug kritis terdokumentasi:

| File | Frozen sejak |
|---|---|
| `CameraSessionController.swift` | M-010 |
| `CapturePipeline.swift` | M-010 |
| `CameraPreviewLayerView.swift` | M-010 |
| `CameraOrientationCoordinator.swift` | M-010 |
| `WorkflowOrchestrator.swift` | M-011 (architecture) |
| `CapturedPhotoStore.swift` | M-011 |
| `EditingCapability.swift` | M-012 |
| `EditingRuntimeProtocol.swift` | M-012 |

Ref: `docs/platform/PLATFORM_BASELINE_V1.md`
