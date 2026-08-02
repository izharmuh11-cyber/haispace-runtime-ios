# Platform Baseline v1.0
### Haispace Runtime iOS — Effective: 2026-08-02

> Dokumen ini menyatakan bahwa komponen-komponen di bawah telah dievaluasi dan dianggap **stabil untuk production milestone**.
>
> Setelah dokumen ini berlaku, tidak ada perubahan arsitektur yang boleh dilakukan pada komponen yang dibekukan kecuali ada bug kritis yang terverifikasi di perangkat nyata.

---

## Komponen yang Dibekukan

### 1. Camera Foundation
**File kanonik**: `CameraCapabilityService`, `CameraOrientationCoordinator`, `CameraPreviewLayerView`

| Kontrak | Detail |
|---|---|
| **Tanggung jawab** | Mengambil satu foto per `requestCapture(correlationId:)`. Menyimpan path ke `CapturedPhotoStore.latestCapturedPhotoPath`. |
| **Tidak boleh** | Camera tidak boleh mengetahui Session, Package, Timer, atau P2P. |
| **Entry point tunggal** | `CameraCapabilityService.shared.requestCapture(correlationId:)` |
| **Preview** | `CameraPreviewLayerView` hanya merender `AVCaptureSession`. Tidak ada logika di dalamnya. |
| **Orientasi** | `CameraOrientationCoordinator` mengatur rotasi preview dan capture. Tidak disentuh kecuali bug kritis. |

---

### 2. Single Runtime Workflow
**File kanonik**: `WorkflowOrchestrator`, `WorkflowIntent`, `WorkflowStage`, `WorkflowRouteMapper`

| Kontrak | Detail |
|---|---|
| **Tanggung jawab** | Menerima `WorkflowIntent` dari View. Mengubah `WorkflowStage`. Me-routing `AppState.currentRoute`. |
| **Tidak boleh** | Orchestrator tidak boleh membaca UI state secara langsung. Tidak boleh tahu tentang SwiftUI. |
| **Entry point tunggal** | `appState.send(_ intent: WorkflowIntent)` — satu-satunya jalur perubahan workflow dari View. |
| **Aturan stage** | Stage hanya bergerak maju kecuali ada `abort` atau `reset` intent. |

---

### 3. Session Timer
**File kanonik**: `SessionTimer`, `TimerEvent`

| Kontrak | Detail |
|---|---|
| **Tanggung jawab** | Menghitung mundur waktu. Memancarkan `tick`, `paused`, `resumed`, `finished`. |
| **Tidak boleh** | Timer tidak boleh tahu domain apapun: Session, Camera, Payment, Package. |
| **Owner tunggal** | `WorkflowOrchestrator` adalah satu-satunya yang boleh memanggil `startSessionCountdown`, `stopSessionCountdown`, `pauseSessionCountdown`, `resumeSessionCountdown`. |
| **Konsumsi UI** | View membaca `appState.sessionContext.remainingSeconds`. View tidak pernah menyentuh `SessionTimer` secara langsung. |

---

### 4. Captured Photo Store
**File kanonik**: `CapturedPhotoStore`, `PhotoEvent`, `CapturedPhoto`

| Kontrak | Detail |
|---|---|
| **Tanggung jawab** | Satu-satunya pemilik data foto yang telah diambil. |
| **Tidak boleh** | Store tidak boleh tahu sumber foto (iPad Camera, P2P, USB, Cloud). |
| **Entry point tunggal** | `CapturedPhotoStore.shared.receivePhotoEvent(_:)` untuk semua sumber foto. |
| **Konsumsi UI** | View membaca `CapturedPhotoStore.shared.capturedPhotos` secara langsung (Observable). |

---

### 5. P2P Transport
**File kanonik**: `P2PMessageRouter`, `P2PStore`, `P2PCapabilityProtocol`

| Kontrak | Detail |
|---|---|
| **Tanggung jawab** | Routing pesan antara iPad dan iPhone. Menyediakan `AsyncStream` per message type. |
| **Tidak boleh** | Router tidak boleh tahu tentang Session, Workflow, atau foto. Dia hanya mengirim dan menerima bytes. |
| **Photo flow** | P2P → `WorkflowOrchestrator.startPhotoInputListening()` → `CapturedPhotoStore.receivePhotoEvent()`. P2P tidak pernah langsung menulis ke Store. |

---

### 6. AppState
**File kanonik**: `AppState.swift`

| Kontrak | Detail |
|---|---|
| **Tanggung jawab** | UI Navigation (`currentRoute`). App lifecycle (`setup()`). Intent dispatch ke Runtime. |
| **Tidak boleh** | AppState tidak boleh membuat keputusan bisnis. Tidak boleh menyimpan data foto. Tidak boleh mengetahui Session domain. |
| **SessionContext** | `appState.sessionContext` adalah snapshot read-only dari WorkflowOrchestrator — direfresh setiap `send()`. View membaca ini untuk package info, queue, dan timer. |

---

## Aturan Platform Freeze

> [!IMPORTANT]
> **Rule #1**: Tidak ada perubahan pada komponen di atas kecuali ada bug yang diverifikasi di perangkat nyata (bukan simulator).

> [!IMPORTANT]
> **Rule #2**: Setiap capability baru (Frame Engine, Printer, Cloud) wajib berkomunikasi melalui `WorkflowOrchestrator`. Tidak ada capability baru yang boleh mengakses `CapturedPhotoStore` secara langsung tanpa melalui `PhotoEvent`.

> [!IMPORTANT]
> **Rule #3**: Setiap capability baru wajib mengikuti prinsip: **"Tidak tahu domain yang lain."** Frame Engine tidak perlu tahu Camera. Printer tidak perlu tahu Session. Cloud tidak perlu tahu Timer.

> [!CAUTION]
> **Larangan keras**: Tidak boleh ada "God Object" baru yang menampung lebih dari satu tanggung jawab. M-011 membuktikan betapa mahalnya biaya membongkar sebuah God Object.

---

## Kontrak Antar Layer (Aliran Data Resmi)

```
View Layer
    │  appState.send(intent:)
    ▼
AppState
    │  runtime.orchestrator.handleIntent(intent)
    ▼
WorkflowOrchestrator
    ├── startSessionCountdown()  →  SessionTimer  →  TimerEvent
    ├── startPhotoInputListening()  →  P2PMessageRouter  →  PhotoEvent  →  CapturedPhotoStore
    └── requestCapture()  →  CameraCapabilityService  →  PhotoEvent  →  CapturedPhotoStore

CapturedPhotoStore
    │  Observable @Published capturedPhotos
    ▼
View Layer (reads only)
```

Tidak ada jalur data yang melewati layer ini secara terbalik.

---

## Roadmap ke Depan (berdasarkan Platform Baseline v1.0)

| Milestone | Deskripsi | Bergantung pada |
|---|---|---|
| **M-012** | Frame Engine | CapturedPhotoStore, WorkflowOrchestrator |
| **M-013** | Editing Pipeline (Filter, LUT) | M-012, CapturedPhotoStore |
| **M-014** | Print Pipeline | M-012, WorkflowOrchestrator |
| **M-015** | Cloud Delivery | WorkflowOrchestrator |
| **M-016** | iPhone Camera Node | CameraCapabilityProtocol (sudah ada) |
| **M-017** | Operator Mission Control v2 | AppState, WorkflowOrchestrator |

Setiap milestone di atas **menambah capability**, bukan membongkar fondasi.

---

> **Platform Baseline v1.0 berlaku efektif sejak commit `0f1dca1`.**
>
> Dokumen ini disetujui oleh: GPT (Chief Product Architect) & Antigravity (Lead Platform Engineer)
>
> Review berikutnya: setelah M-012 Frame Engine selesai (Platform Baseline v1.1).
