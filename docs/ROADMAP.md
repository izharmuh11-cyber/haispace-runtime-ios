# Haispace Platform — Master Roadmap
**Terakhir diperbarui: 2026-08-02 | Oleh: Chief Product Architect + Antigravity**

---

## Platform Vision

> Haispace bukan sekadar aplikasi photobooth.
> Haispace adalah **platform** yang terdiri dari tiga sub-platform yang saling terpisah tetapi saling mendukung.

```
                    Haispace Platform
                           │
          ┌────────────────┼────────────────┐
          │                │                │
          ▼                ▼                ▼
  Runtime Platform   Authoring Platform   Event Management
  (di booth)         (tim desain)         (operator/admin)
```

---

## 1. Runtime Platform

**Berjalan di iPad booth. Target: Customer (tamu).**

```
Camera
    ↓
Workflow
    ↓
Editing / Frame
    ↓
Filter
    ↓
Printer
    ↓
Cloud Delivery
```

Milestone: M-010 → M-012 → M-013 → M-014 → M-015 → M-016 → M-017

---

## 2. Authoring Platform

**Dipakai tim desain untuk membuat Frame Package. Target: Internal.**

```
Upload PNG transparan
    ↓
FrameSlotDetector (auto-detect)
    ↓
Visual Preview + Fine-tune
    ↓
Generate Frame Package
    ↓
Publish ke CDN
```

Milestone: M-012A

**Output:** `Frame Package` (bukan hanya PNG)

```
wedding-classic/
    ├── frame.png           ← overlay PNG (alpha channel)
    ├── template.json       ← slot coordinates (auto-generated)
    ├── thumbnail.webp      ← preview kecil untuk UI picker
    ├── preview.jpg         ← full preview dengan foto contoh
    └── manifest.json       ← metadata package
```

---

## 3. Event Management Platform

**Dipakai operator untuk setup event. Target: Operator Haispace.**

```
Buat Event baru
    ↓
Pilih Theme / Package
    ↓
Frame Collection aktif
    ↓
Filter Collection aktif
    ↓
Printer Setting aktif
    ↓
Pricing aktif
    ↓
Branding aktif
```

Operator tidak lagi setting satu per satu. Pilih `Wedding Package A` → semua aktif otomatis.

Milestone: M-018 (planned, setelah Runtime dan Authoring stabil)

---

---

## Milestone Roadmap (Urutan)

---

### ✅ M-010 — Native Camera Foundation
**Status: SELESAI & FROZEN**

Platform Freeze v1.0 aktif:
- `CameraSessionController.swift`
- `CapturePipeline.swift`
- `CameraPreviewLayerView.swift`
- `CameraOrientationCoordinator.swift`

---

### ✅ M-011 — Single Runtime Workflow
**Status: SELESAI** | Commit: `0f1dca1`

`SessionStore` dihapus. Zero bridge. Zero legacy. Semua state mengalir melalui `WorkflowOrchestrator`.

---

### 🔄 M-012 — Frame Engine (Runtime Platform)
**Status: Engineering Complete — Waiting for Production Frame Assets & Device Validation**

Scope: Frame Engine yang merender. Tidak lebih.

**Definition of Done (12 kriteria):**

| # | Kriteria | Status |
|---|---|---|
| 1 | Arsitektur Editing stabil (zero hidden dependency) | ✅ |
| 2 | Runtime tidak tahu domain (Session, Guest, Package) | ✅ |
| 3 | `RenderedOutput` rich model | ✅ |
| 4 | `PhotoReference` value type | ✅ |
| 5 | `outputDirectory` di-inject | ✅ |
| 6 | Platform Baseline v1.0 tidak dilanggar | ✅ |
| 7 | Validator 7/7 checks | ⏳ iPad |
| 8 | 3 template render tanpa kode baru | ⏳ iPad |
| 9 | Preview ↔ Export konsisten | ⏳ iPad |
| 10 | Benchmark < 2000ms | ⏳ iPad |
| 11 | **Hasil render dilihat visual manusia di iPad** | ❌ |
| 12 | Log tersimpan di R2 | ❌ |

**Post-M-012 improvement (dijadwalkan):**
- PNG LRU Cache di `CoreImageEditingRuntime` — menghindari re-read disk setiap render

> **Catatan:** M-012 akan segera mendukung Frame Package format (membaca `manifest.json` dan `template.json`) begitu M-012A selesai — tanpa perubahan engine.

---

### 📋 M-012A — Frame Authoring Platform (Authoring Platform)
**Status: PLANNED — mulai setelah M-012 ditutup**

**Target user: Tim Desain** (bukan tamu booth)

**Output utama: Frame Package**

```
{frameId}/
    ├── frame.png
    ├── template.json    ← auto-generated oleh FrameSlotDetector
    ├── thumbnail.webp
    ├── preview.jpg
    └── manifest.json
```

`manifest.json`:
```json
{
  "id": "wedding-classic",
  "name": "Wedding Classic",
  "version": "1.0.0",
  "author": "Haispace Design Team",
  "category": "Wedding",
  "slotCount": 2,
  "aspectRatio": "3:4",
  "tags": ["wedding", "gold", "classic"]
}
```

**Prinsip:**
> "Designer cukup membuat PNG transparan. Selesai. Sisanya pekerjaan sistem."

**Deliverable:**
- `FrameSlotDetector` — BFS scan alpha=0, output slot coordinates
- `FramePackageWriter` — generate seluruh folder package
- `FrameAuthoringService` — orchestrator workflow
- Visual Review UI (platform TBD)
- CDN publish pipeline

**Dampak ke Runtime:**
- `CoreImageEditingRuntime` membaca `manifest.json` + `template.json` — **tanpa perubahan engine**
- `PlatformDiagnosticsService` bisa menambah `FramePackageValidator`

**Dampak ke Event Management:**
- Operator memilih Frame Package berdasarkan `manifest.json` — tidak perlu pilih file satu per satu

---

### 📋 M-013 — Filter / Editing Experience (Runtime Platform)
**Status: PLANNED**

LUT Metal filter di atas `RenderedOutput`.

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

### 📋 M-014 — Print Experience (Runtime Platform)
**Status: PLANNED**

`PrinterCapability` aktif. `RenderedOutput.fullPath` → AirPrint / DNP thermal.

---

### 📋 M-015 — Cloud Delivery (Runtime Platform)
**Status: PLANNED**

`CloudCapability` aktif. `RenderedOutput` → R2 → QR code.

---

### 📋 M-016 — iPhone Camera Node (Runtime Platform)
**Status: PLANNED**

iPhone sebagai kamera eksternal via P2P. Interface `CapturedPhotoStore` tidak berubah.

---

### 📋 M-017 — Runtime Certification
**Status: PLANNED (setelah M-014 + M-015)**

Full end-to-end certification. `PlatformDiagnosticsService.runAll()` = semua hijau.

```
✅ Haispace Runtime Platform v1.0 Certified
```

---

### 📋 M-018 — Event Management Platform
**Status: LONG-TERM PLANNED**

Operator setup event sekali — semua aktif:

```
Pilih "Wedding Package A"
    ↓
Frame Package: wedding-classic/ aktif
Filter Collection: "Soft Warm" aktif
Printer: DNP DS-RX1 aktif
Branding: logo wedding aktif
Pricing: Rp 65.000/foto aktif
```

Tidak ada lagi konfigurasi manual per-session.

---

## Platform Baseline v1.0 — Frozen Components

| File | Frozen sejak |
|---|---|
| `CameraSessionController.swift` | M-010 |
| `CapturePipeline.swift` | M-010 |
| `CameraPreviewLayerView.swift` | M-010 |
| `CameraOrientationCoordinator.swift` | M-010 |
| `WorkflowOrchestrator.swift` | M-011 |
| `CapturedPhotoStore.swift` | M-011 |
| `EditingCapability.swift` | M-012 |
| `EditingRuntimeProtocol.swift` | M-012 |

Ref: `docs/platform/PLATFORM_BASELINE_V1.md`

---

## Kutipan Arsitektural

> *"Mulai setelah ini, setiap milestone akan semakin terasa sebagai pembangunan produk, bukan lagi pembuktian arsitektur."*
> — Chief Product Architect, setelah M-011

> *"Haispace sekarang terbagi menjadi dua produk yang berbeda: Runtime Platform dan Authoring Platform. Dulu keduanya bercampur. Sekarang kita punya kesempatan memisahkannya."*
> — Chief Product Architect, setelah Product Archaeology M-012

> *"Di masa depan kita tidak lagi berbicara tentang 'upload PNG', tetapi mengelola Frame Package, yang jauh lebih siap untuk berkembang menjadi platform berskala besar."*
> — Chief Product Architect, 2026-08-02
