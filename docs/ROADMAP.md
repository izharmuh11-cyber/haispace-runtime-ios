# Haispace Platform — Master Roadmap
**Terakhir diperbarui: 2026-08-02 | Oleh: Chief Product Architect + Antigravity**

---

## Platform DNA

> **"Cloud stores facts. Runtime executes behavior."**

Haispace bukan satu aplikasi. Haispace adalah **satu platform yang terdiri dari beberapa produk** yang bertemu di konstitusi yang sama.

```
                    Haispace Platform
                   (Constitutional Repo)
                           │
     ┌─────────────────────┼─────────────────────┐
     │                     │                     │
     ▼                     ▼                     ▼
Runtime Track         Cloud Track          Authoring Track
(M-xxx)               (C-xxx)              (A-xxx)
     │                                          │
     └──────────────────────────────────────────┘
                           │
                    Integration Track
                        (I-xxx)
```

---

## Prinsip Pemisahan Track

| Track | Repository | Target User | Bergantung Pada |
|---|---|---|---|
| **Runtime** | `haispace-runtime-ios` | Customer (tamu booth) | — (berdiri sendiri) |
| **Cloud** | `hsp-cloud` | Platform operator | Runtime (menerima fakta dari Runtime) |
| **Integration** | `haispace-runtime-ios` | Booth (iPad) | Cloud (C-002 harus selesai) |
| **Authoring** | TBD | Tim desain | Cloud + Integration |

---

---

# Runtime Track (M-xxx)

> Runtime adalah produk yang 100% berjalan di dalam iPad.
> Tidak membutuhkan backend untuk beroperasi.
> Semua milestone M-xxx harus bisa dijalankan dalam mode offline penuh.

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

`SessionStore` dihapus. Zero bridge. Zero legacy.
Semua state mengalir melalui `WorkflowOrchestrator`.

---

### 🔄 M-012 — Frame Engine
**Status: Engineering Complete — Waiting for Production Frame Assets & Device Validation**

Frame Engine yang merender. Platform-agnostic. Zero UI dependency.

> **Catatan:** M-012 menggunakan frame dari local disk (manual drop).
> Frame dari Cloud Manifest akan tersedia setelah I-001 selesai.

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
| 12 | Log tersimpan | ❌ |

**Post-M-012 improvement (dijadwalkan):**
- PNG LRU Cache di `CoreImageEditingRuntime`

---

### 📋 M-013 — Filter Experience
**Status: PLANNED — mulai setelah M-012 ditutup**

LUT/Metal filter pipeline. Customer memilih filter sebelum print.

```
RenderedOutput
    ↓
FilterCapability (LUT / Metal)
    ↓
FilteredOutput
```

---

### 📋 M-014 — Print Experience
**Status: PLANNED — mulai setelah M-013**

`PrinterCapability` aktif. `RenderedOutput.fullPath` → AirPrint / DNP thermal.

```
FilteredOutput
    ↓
PrinterCapability
    ↓
AirPrint / DNP SDK
```

---

---

# Cloud Track (C-xxx)

> Cloud menyimpan fakta. Cloud tidak pernah menentukan langkah workflow.
> Setiap Phase Cloud berdiri sendiri dan dapat dikerjakan paralel dengan Runtime Track.
> Sumber: `haispace-platform/cloud/BACKEND_IMPLEMENTATION_PLAN.md`

---

### 📋 C-001 — Infrastructure Foundation
**Status: PLANNED**
**Repository: `hsp-cloud`**

Target: Backend siap menerima Booth pertama kali.

```
C-001 mencakup:
    ├── Device Registration   (POST /v1/devices)
    ├── Authentication        (JWT + apiKey)
    ├── Organization          (multi-tenant root)
    ├── Operator Management   (role: owner | manager | staff)
    └── Booth Management      (status lifecycle)
```

**DoD:** Booth nyata (iPad dev) dapat register dan berautentikasi ke backend.

---

### 📋 C-002 — Content Delivery
**Status: PLANNED — mulai setelah C-001**
**Repository: `hsp-cloud`**

Target: Booth dapat mengambil Manifest dan Asset untuk memulai session.

```
C-002 mencakup:
    ├── Event Management      (draft → active → completed → archived)
    ├── Manifest API          (create draft, publish, version monotonic)
    ├── Asset API             (upload, checksum, download-url, presigned)
    └── Package API           (pricing, captureLimit, deliveryMethods)
```

**Ini adalah milestone yang membuat Manifest pertama kali "hidup".**

Manifest pada C-002 sudah bisa memuat:
```
Event: Wedding A
Manifest v1
    ├── Frame Asset(s)
    ├── Filter LUT Asset(s)
    ├── Printer Profile Asset
    └── Branding Asset
```

**DoD:** Booth dapat fetch Manifest yang berisi semua jenis asset, dan men-download pre-signed URL per asset.

> **Catatan:** C-002 sengaja dikerjakan setelah M-013 dan M-014 selesai,
> sehingga saat Manifest pertama kali dipakai, ia sudah membawa Frame + Filter + Printer sekaligus —
> bukan hanya satu jenis asset.

---

### 📋 C-003 — Runtime Data Ingest
**Status: PLANNED — mulai setelah C-002**
**Repository: `hsp-cloud`**

Target: Runtime dapat mengirim fakta ke Cloud. Cloud menjadi mirror.

```
C-003 mencakup:
    ├── Session Archive API   (ingest SessionSnapshot, idempotent)
    ├── Domain Event Upload   (batch, append-only, idempotency via eventId)
    └── Audit Upload          (batch, 7-year retention)
```

**DoD:** Runtime dapat upload SessionSnapshot setelah payment + upload DomainEvent batch.

---

### 📋 C-004 — Operations & Analytics
**Status: PLANNED — mulai setelah C-003**
**Repository: `hsp-cloud` + `hsp-mission-control`**

Target: Operator dapat memantau platform via Mission Control.

```
C-004 mencakup:
    ├── Read-only session/event/audit endpoints untuk Mission Control
    ├── Analytics projections (DailySessionSummary, RevenueByEvent, dll.)
    └── Booth health dashboard
```

---

---

# Integration Track (I-xxx)

> Milestone yang menghubungkan Runtime dengan Cloud.
> Bergantung pada: C-002 (Manifest + Asset API) sudah production-ready.
> Berjalan di `haispace-runtime-ios`.

---

### 📋 I-001 — Runtime Asset Sync
**Status: PLANNED — mulai setelah C-002 selesai**
**Repository: `haispace-runtime-ios`**

Runtime membaca Manifest dari Cloud dan men-cache Asset secara lokal.

```
App Launch / setiap 1 jam
    ↓
ManifestService.fetchLatest(boothId)
    ↓
Bandingkan assetRefs vs cache lokal (by checksum)
    ↓
AssetDownloader.download(diff)   ← hanya asset yang berubah
    ↓
Simpan ke ~/Library/Caches/HaispaceAssets/{assetId}/
    ↓
CoreImageEditingRuntime baca dari cache
    ↓
Session berjalan offline
```

**Yang dibangun:**
- `ManifestService` — fetch + version pinning per session
- `AssetDownloader` — checksum validation + delta download
- `AssetCache` — LRU, crash-safe, disk-backed
- `ManifestVersionPin` — session aktif tidak dapat manifest baru

**Invariant (dari SYNC_STRATEGY.md):**
- Session yang sedang berjalan **tidak boleh** mendapat manifest baru
- Manifest baru hanya berlaku untuk session berikutnya
- Wajib online hanya saat: Device Registration + Manifest Fetch pertama

**Dampak ke Runtime:** Zero breaking change — `CoreImageEditingRuntime` tetap menerima `framePNGPath: String`. Yang berubah hanya source of path (dari manual disk → `AssetCache`).

---

---

# Authoring Track (A-xxx)

> Milestone untuk tim desain — bukan untuk customer.
> Bergantung pada: I-001 selesai (format asset di Cloud sudah final).
> Dengan I-001 sudah berjalan, output Authoring langsung kompatibel tanpa mendesain format dua kali.

---

### 📋 A-001 — Asset Authoring Platform
**Status: PLANNED — mulai setelah I-001 selesai**
**Repository: TBD (Authoring tool)**

Target user: Tim Desain (bukan tamu booth).

```
Upload file aset (PNG transparan, LUT file, dll.)
    ↓
AssetSlotDetector (auto-detect slot dari alpha channel)
    BFS + PCA algorithm — porting dari legacy web
    ↓
Visual Preview + Fine-tune (drag-drop slot editor)
    ↓
AssetPackageWriter (generate package + checksum)
    ↓
Publish ke HaiBackend (POST /v1/assets)
    ↓
Asset tersedia di Asset library Mission Control
    ↓
Operator assign ke Manifest per Event
```

**Prinsip:**
> "Designer cukup membuat PNG transparan. Selesai. Sisanya pekerjaan sistem."

**Algoritma yang sama berlaku untuk semua jenis asset:**
- Frame (PNG dengan alpha slot)
- Overlay / Sticker / Border / Watermark
- Filter (LUT)
- Branding (logo, backdrop)
- Future asset types

**Deliverable:**
- `AssetSlotDetector` — BFS scan alpha=0, output `[SlotCoordinate]`
- `AssetPackageWriter` — generate seluruh package + `asset-manifest.json`
- `AssetAuthoringService` — orchestrator workflow
- Visual Review UI

---

---

# Platform Baseline v1.0 — Frozen Components

File-file berikut **tidak boleh dimodifikasi** kecuali ada bug kritis terdokumentasi:

| File | Frozen sejak | Track |
|---|---|---|
| `CameraSessionController.swift` | M-010 | Runtime |
| `CapturePipeline.swift` | M-010 | Runtime |
| `CameraPreviewLayerView.swift` | M-010 | Runtime |
| `CameraOrientationCoordinator.swift` | M-010 | Runtime |
| `WorkflowOrchestrator.swift` | M-011 | Runtime |
| `CapturedPhotoStore.swift` | M-011 | Runtime |
| `EditingCapability.swift` | M-012 | Runtime |
| `EditingRuntimeProtocol.swift` | M-012 | Runtime |

Ref: `docs/platform/PLATFORM_BASELINE_V1.md`

---

# Kutipan Arsitektural

> *"Mulai setelah ini, setiap milestone akan semakin terasa sebagai pembangunan produk, bukan lagi pembuktian arsitektur."*
> — Chief Product Architect, setelah M-011

> *"Cloud stores facts. Runtime executes behavior."*
> — Platform DNA, dikodifikasi di `haispace-platform/cloud/CLOUD_CONTRACT.md`

> *"Asset Sync bukan milik Runtime. Asset Sync adalah implementasi Cloud Platform."*
> — Chief Product Architect, 2026-08-02

> *"Haispace bukan lagi satu aplikasi, melainkan satu platform yang terdiri dari beberapa produk. Roadmap kita juga harus mencerminkan struktur tersebut."*
> — Chief Product Architect, 2026-08-02
