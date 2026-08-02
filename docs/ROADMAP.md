# Haispace Runtime — Runtime Roadmap
**Repository:** `haispace-runtime-ios`
**Terakhir diperbarui: 2026-08-02**

---

> Dokumen ini hanya berisi **Runtime milestones** (M-xxx).
> Untuk gambaran platform lengkap (Cloud, Integration, Authoring),
> lihat `haispace-platform/MASTER_ROADMAP.md`.

---

## Status Ringkasan

| Milestone | Nama | Status |
|---|---|---|
| M-010 | Native Camera Foundation | ✅ Selesai |
| M-011 | Single Runtime Workflow | ✅ Selesai |
| M-012 | Frame Engine | 🔄 Engineering Complete — Validation Pending |
| M-013 | Filter Experience | 📋 Planned |
| M-014 | Print Experience | 📋 Planned |

---

## ✅ M-010 — Native Camera Foundation
**Status: SELESAI & FROZEN**

Platform Freeze v1.0 aktif.

**Files frozen:**
- `CameraSessionController.swift`
- `CapturePipeline.swift`
- `CameraPreviewLayerView.swift`
- `CameraOrientationCoordinator.swift`

---

## ✅ M-011 — Single Runtime Workflow
**Status: SELESAI** | Commit: `0f1dca1`

`SessionStore` dihapus. Zero bridge. Zero legacy.
Semua state mengalir melalui `WorkflowOrchestrator`.

**Files frozen (added at M-011):**
- `WorkflowOrchestrator.swift`
- `CapturedPhotoStore.swift`

---

## 🔄 M-012 — Frame Engine
**Status: Engineering Complete — Waiting for Production Assets & Device Validation**

Frame Engine yang merender frame di atas foto. Platform-agnostic. Zero UI dependency.

**Definition of Done (12 kriteria):**

| # | Kriteria | Status |
|---|---|---|
| 1 | Arsitektur Editing stabil (zero hidden dependency) | ✅ |
| 2 | Runtime tidak tahu domain (Session, Guest, Package) | ✅ |
| 3 | `RenderedOutput` rich model | ✅ |
| 4 | `PhotoReference` value type | ✅ |
| 5 | `outputDirectory` di-inject | ✅ |
| 6 | Platform Baseline v1.0 tidak dilanggar | ✅ |
| 7 | Validator 7/7 checks | ⏳ Butuh iPad |
| 8 | 3 template render tanpa kode baru | ⏳ Butuh frame aset |
| 9 | Preview ↔ Export konsisten | ⏳ Butuh iPad |
| 10 | Benchmark < 2000ms | ⏳ Butuh iPad |
| 11 | **Hasil render dilihat visual manusia di iPad** | ❌ Pending |
| 12 | Log tersimpan di `RuntimeTimelineLogger` | ❌ Pending |

**Blocked on:** 3 frame PNG produksi dari tim desain (`single`, `strip`, `quad`).

**Files frozen (added at M-012):**
- `EditingCapability.swift`
- `EditingRuntimeProtocol.swift`
- `CoreImageEditingRuntime.swift`

---

## 📋 M-013 — Filter Experience
**Status: PLANNED — mulai setelah M-012 ditutup**

LUT/Metal filter pipeline. Customer memilih filter sebelum cetak.

```
CapturedPhoto
    ↓
FilterCapability (LUT / Metal)
    ↓
FilteredOutput → masuk ke RenderedOutput pipeline
```

---

## 📋 M-014 — Print Experience
**Status: PLANNED — mulai setelah M-013**

`PrinterCapability` aktif. Foto hasil render dikirim ke printer fisik.

```
RenderedOutput
    ↓
PrinterCapability
    ↓
AirPrint / DNP Thermal SDK
```

---

## Platform Baseline v1.0

File-file berikut **tidak boleh dimodifikasi** kecuali ada bug kritis terdokumentasi:

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
