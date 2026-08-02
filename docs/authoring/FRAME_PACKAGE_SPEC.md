# Frame Package Specification
### Haispace Authoring Platform — M-012A
**Versi: 1.0 | Status: PLANNED | Berlaku mulai: M-012A**

---

> **Konteks keputusan:**
> Hasil product archaeology menunjukkan bahwa legacy system sudah punya Frame Authoring System yang canggih (BFS+PCA auto-detect, visual editor, R2 sync). Chief memutuskan untuk tidak hanya mereplikasi, tapi **meningkatkan** konsepnya menjadi Frame Package — satu unit yang self-contained, versioned, dan cross-platform.

---

## Apa itu Frame Package?

Bukan lagi sekadar file PNG + koordinat slot.

**Frame Package** adalah satu folder yang berisi semua yang dibutuhkan oleh:
- **Runtime Platform** untuk merender
- **Event Management Platform** untuk memilih frame
- **CDN** untuk mendistribusikan
- **Cloud Renderer** untuk render di server

```
{frame-id}/
    ├── frame.png           ← Overlay PNG (wajib)
    ├── template.json       ← Slot coordinates (auto-generated)
    ├── thumbnail.webp      ← Preview kecil untuk UI picker
    ├── preview.jpg         ← Full preview dengan foto contoh
    └── manifest.json       ← Metadata package (wajib)
```

---

## File 1: `manifest.json` (Wajib)

```json
{
  "id": "wedding-classic",
  "name": "Wedding Classic",
  "version": "1.0.0",
  "author": "Haispace Design Team",
  "category": "Wedding",
  "slotCount": 2,
  "aspectRatio": "3:4",
  "canvasWidth": 1080,
  "canvasHeight": 1440,
  "tags": ["wedding", "gold", "classic"],
  "minAppVersion": "1.0",
  "createdAt": "2026-08-02T00:00:00Z",
  "updatedAt": "2026-08-02T00:00:00Z"
}
```

| Field | Type | Wajib | Keterangan |
|---|---|---|---|
| `id` | String | ✅ | Unik, lowercase, hyphen. Dipakai sebagai folder name dan CDN key. |
| `name` | String | ✅ | Display name di UI picker |
| `version` | String | ✅ | SemVer — runtime bisa cache invalidate via versi |
| `author` | String | ❌ | Untuk audit trail |
| `category` | String | ✅ | "Wedding", "Birthday", "Corporate", "Graduation", "Estetik" |
| `slotCount` | Int | ✅ | Berapa foto yang dibutuhkan template ini |
| `aspectRatio` | String | ✅ | "3:4", "4:3", "1:1" — untuk filtering di UI |
| `canvasWidth` | Int | ✅ | Ukuran canvas output (pixels) |
| `canvasHeight` | Int | ✅ | Ukuran canvas output (pixels) |
| `tags` | [String] | ❌ | Untuk search dan filtering |
| `minAppVersion` | String | ❌ | Minimum versi app yang mendukung package ini |

---

## File 2: `template.json` (Wajib — auto-generated oleh FrameSlotDetector)

```json
{
  "schemaVersion": "1",
  "canvasWidth": 1080,
  "canvasHeight": 1440,
  "slots": [
    {
      "id": "slot-1",
      "x": 36,
      "y": 36,
      "width": 1008,
      "height": 680,
      "rotationDegrees": 0,
      "cropGravityX": 0.5,
      "cropGravityY": 0.5
    },
    {
      "id": "slot-2",
      "x": 36,
      "y": 724,
      "width": 1008,
      "height": 680,
      "rotationDegrees": 0,
      "cropGravityX": 0.5,
      "cropGravityY": 0.5
    }
  ],
  "detectedAt": "2026-08-02T00:00:00Z",
  "detectedBy": "FrameSlotDetector v1.0"
}
```

> [!NOTE]
> `template.json` tidak perlu ditulis manual oleh desainer. `FrameSlotDetector` akan menghasilkannya secara otomatis dari area transparan `frame.png`.

---

## File 3: `frame.png` (Wajib)

PNG-24 dengan alpha channel. Area slot = fully transparent (alpha=0). Area dekorasi = opaque.

Lihat `docs/design/FRAME_ASSET_SPEC.md` untuk panduan desain.

---

## File 4: `thumbnail.webp` (Recommended)

WebP, max 400×400px. Auto-generated oleh `FramePackageWriter` menggunakan Sharp (atau CoreImage di native).

Dipakai oleh:
- Frame picker UI di Runtime (lazy-loaded)
- Frame catalog di Event Management

---

## File 5: `preview.jpg` (Recommended)

JPEG, resolusi penuh. Full preview dengan foto contoh (silhouette atau stock photo yang safe).

Dipakai oleh:
- Halaman detail frame di Authoring UI
- Event Management untuk review sebelum publish

---

## CDN Structure

```
cdn.haispace.id/
    └── frames/
        ├── default/                  ← frame bawaan (selalu ada)
        │   ├── single-white/
        │   │   ├── manifest.json
        │   │   ├── template.json
        │   │   ├── frame.png
        │   │   ├── thumbnail.webp
        │   │   └── preview.jpg
        │   ├── strip-minimal/
        │   └── quad-grid/
        │
        └── {eventSlug}/              ← frame event-specific
            ├── wedding-classic/
            ├── wedding-floral/
            └── wedding-gold/
```

**Lookup order di Runtime:**
```
1. {eventSlug}/{frameId}/   (event-specific)
2. default/{frameId}/       (fallback ke default)
3. Bundle resource          (absolute fallback, 3 frame bawaan)
```

---

## Local Storage di iPad

```
~/Library/Caches/HaispaceFrames/
    ├── single-white/
    │   ├── manifest.json
    │   ├── template.json
    │   ├── frame.png
    │   ├── thumbnail.webp
    │   └── preview.jpg
    ├── strip-minimal/
    └── quad-grid/
```

Runtime **selalu baca dari local cache**. Tidak ada network call saat render. CDN hanya diakses saat:
- Pertama kali app dibuka (download default frames)
- Event baru di-assign ke booth
- Versi frame di manifest berbeda dengan cache

---

## Versioning

Frame Package menggunakan SemVer:

```
1.0.0 → initial release
1.0.1 → minor fix (thumbnail, preview — tidak mengubah template)
1.1.0 → slot coordinates berubah
2.0.0 → canvas size berubah (breaking change)
```

Runtime akan invalidate cache dan re-download jika `manifest.version` berbeda dari cache.

---

## Swift Model (untuk M-012A planning)

```swift
// FramePackage.swift — akan dibuat di M-012A
public struct FramePackage: Codable, Sendable, Identifiable {
    public let manifest: FrameManifest
    public let template: FrameTemplate
    public let localDirectory: URL
    
    public var id: String { manifest.id }
    public var framePNGPath: String { localDirectory.appendingPathComponent("frame.png").path }
    public var thumbnailPath: String { localDirectory.appendingPathComponent("thumbnail.webp").path }
}

public struct FrameManifest: Codable, Sendable {
    public let id: String
    public let name: String
    public let version: String
    public let category: String
    public let slotCount: Int
    public let aspectRatio: String
    public let canvasWidth: Int
    public let canvasHeight: Int
    public let tags: [String]
}
```

---

## Dampak ke Komponen yang Sudah Ada

| Komponen | Dampak | Action |
|---|---|---|
| `CoreImageEditingRuntime` | Baca `template.json` daripada hardcoded slot | Update saat M-012A, zero engine change |
| `FrameReference` | Ubah ke `FramePackage` reference | Backward compat via optional |
| `FrameTemplate` | Sudah sesuai dengan schema `template.json` | ✅ Tidak perlu ubah |
| `DiagnosticsDashboardView` | Tampilkan package catalog | Feature addition |
| `PlatformDiagnosticsService` | Tambah `FramePackageValidator` | Feature addition |

> [!IMPORTANT]
> `CoreImageEditingRuntime` **tidak perlu diubah** untuk mendukung Frame Package. Engine tetap menerima `photoInput: String + frameAssetPath: String`. Yang berubah hanya cara Orchestrator/CapabilityModule membaca path — dari `FramePackage.framePNGPath`.

---

## Timeline

| Phase | Task | Milestone |
|---|---|---|
| Sekarang | Gunakan spec PNG manual (FRAME_ASSET_SPEC.md) untuk 3 frame initial | M-012 closure |
| M-012A Start | Implementasi `FrameSlotDetector` | M-012A |
| M-012A Mid | `FramePackageWriter` + `manifest.json` generation | M-012A |
| M-012A End | CDN publish pipeline + Runtime reads FramePackage | M-012A |
| M-018 | Event Management pilih Frame Package dari catalog | M-018 |

---

> **File ini adalah spesifikasi teknis untuk M-012A.**
> Jika ada perubahan pada schema `manifest.json` atau `template.json`, update file ini terlebih dahulu sebelum implementasi.
