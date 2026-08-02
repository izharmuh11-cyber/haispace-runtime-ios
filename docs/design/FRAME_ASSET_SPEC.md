# Frame Asset Specification
### Haispace Platform — M-012 Frame Engine
**Versi: 1.0 | Status: FINAL — Menunggu produksi aset**

---

> Dokumen ini adalah panduan teknis untuk tim desain yang memproduksi frame PNG.
> Begitu tiga frame final tersedia sesuai spesifikasi ini, tim engineering hanya perlu **drop aset + jalankan Platform Diagnostics**. Tidak ada perubahan kode.

---

## 1. Format File

| Parameter | Nilai |
|---|---|
| **Format** | PNG-24 dengan Alpha Channel |
| **Color Mode** | RGB + Alpha (RGBA) |
| **Color Profile** | sRGB IEC61966-2.1 |
| **Bit Depth** | 8 bit per channel |
| **Kompresi** | PNG lossless (tidak ada JPEG) |
| **Maksimum ukuran file** | 5MB per frame |

> [!IMPORTANT]
> Frame **wajib** memiliki alpha channel (transparansi). Area tempat foto masuk harus fully transparent (alpha = 0). Area dekorasi frame adalah opaque.

---

## 2. Resolusi Canvas

Semua frame menggunakan ukuran canvas yang sama:

```
Width:  1080 px
Height: 1440 px
Aspect: 3:4 (Portrait)
```

> [!NOTE]
> Engine sudah dikonfigurasi untuk canvas 1080×1440 px. Jika resolusi berbeda diperlukan di masa depan, akan ada perubahan `FrameTemplate.canvasWidth/canvasHeight` — bukan perubahan engine.

---

## 3. Tiga Template yang Dibutuhkan

### Template 1: Single Photo
**File:** `frame-single.png`

```
┌────────────────────┐
│  ░░░░░░░░░░░░░░░░  │  ← dekorasi frame (opaque)
│  ░                ░│
│  ░  [TRANSPARAN]  ░│  ← slot foto (alpha = 0)
│  ░   1008 × 1224  ░│
│  ░                ░│
│  ░░░░░░░░░░░░░░░░  │
└────────────────────┘
```

**Slot transparent area:**
- X: 36px, Y: 36px
- Width: 1008px, Height: 1224px

---

### Template 2: Photo Strip (Dual)
**File:** `frame-strip.png`

```
┌────────────────────┐
│  ░░░░░░░░░░░░░░░░  │
│  ░  [TRANSPARAN]  ░│  ← slot 1 (alpha = 0)
│  ░   1008 × 680   ░│
│  ░░░░░░░░░░░░░░░░  │  ← pemisah dekorasi
│  ░  [TRANSPARAN]  ░│  ← slot 2 (alpha = 0)
│  ░   1008 × 680   ░│
│  ░░░░░░░░░░░░░░░░  │
└────────────────────┘
```

**Slot 1:** X: 36px, Y: 36px, W: 1008px, H: 680px
**Slot 2:** X: 36px, Y: 724px, W: 1008px, H: 680px

---

### Template 3: Quad Grid
**File:** `frame-quad.png`

```
┌────────────────────┐
│  [T1] ░░░ [T2]     │  ← slot 1 dan 2 (alpha = 0)
│  494×680    494×680│
│  ░░░░░░░░░░░░░░░░  │  ← pemisah dekorasi
│  [T3] ░░░ [T4]     │  ← slot 3 dan 4 (alpha = 0)
│  494×680    494×680│
└────────────────────┘
```

**Slot 1:** X: 36px,  Y: 36px,  W: 494px, H: 680px
**Slot 2:** X: 550px, Y: 36px,  W: 494px, H: 680px
**Slot 3:** X: 36px,  Y: 724px, W: 494px, H: 680px
**Slot 4:** X: 550px, Y: 724px, W: 494px, H: 680px

---

## 4. Naming Convention

```
frame-{template}.png
```

| Template | Filename |
|---|---|
| Single | `frame-single.png` |
| Strip (2 foto) | `frame-strip.png` |
| Quad Grid (4 foto) | `frame-quad.png` |

**Aturan penamaan:**
- Semua huruf kecil
- Gunakan tanda hubung (`-`), bukan underscore (`_`)
- Tidak ada spasi
- Tidak ada versi number di filename (versioning via folder, bukan nama file)

---

## 5. Folder Structure di iPad

```
~/Library/Caches/HaispaceFrames/
    ├── frame-single.png
    ├── frame-strip.png
    └── frame-quad.png
```

**Path lengkap contoh:**
```
/var/mobile/Containers/Data/Application/{UUID}/Library/Caches/HaispaceFrames/frame-single.png
```

> [!TIP]
> Untuk testing awal, aset bisa di-copy manual via Xcode → Devices → Download Container → paste ke folder Caches/HaispaceFrames/. Untuk production, aset akan di-download otomatis dari CDN via `BoothConfigStore`.

---

## 6. CDN URL Pattern (untuk production download)

```
https://cdn.haispace.id/frames/{eventSlug}/{filename}
```

Contoh:
```
https://cdn.haispace.id/frames/default/frame-single.png
https://cdn.haispace.id/frames/wisuda-binus-2026/frame-single.png
```

> Event-specific frames override default frames. Jika tidak ada event-specific frame, fallback ke `default/`.

---

## 7. Panduan Desain

### Area Aman (Safe Zone)
Slot transparent harus memiliki **clearance minimal 36px** dari tepi canvas di semua sisi. Engine sudah menggunakan 36px sebagai default padding.

### Alpha Gradient
Tepi slot boleh menggunakan alpha gradient untuk efek vignette natural:

```
Tepi slot (alpha = 255) → 4px gradient → area foto (alpha = 0)
```

### Warna Background Canvas
Area di luar slot (background frame) bisa menggunakan warna, gradient, atau elemen dekoratif apapun dalam opaque area.

### Apa yang TIDAK boleh ada di frame PNG:
- ❌ Layer yang di-flatten tanpa alpha channel
- ❌ Area putih solid di tempat slot (harus benar-benar transparent)
- ❌ Resolusi berbeda dari 1080×1440px
- ❌ Format selain PNG

---

## 8. Checklist Sebelum Menyerahkan Aset

Desainer wajib melakukan verifikasi ini sebelum menyerahkan aset ke engineering:

```
☐ Format PNG-24 dengan alpha channel
☐ Resolusi tepat 1080×1440 px
☐ Slot area adalah fully transparent (alpha = 0), bukan putih
☐ Color profile: sRGB
☐ File size < 5MB
☐ Nama file sesuai convention (frame-single.png, frame-strip.png, frame-quad.png)
☐ Test sederhana: buka di browser/Preview, area slot terlihat sebagai checkerboard (transparent)
```

---

## 9. Prosedur Setelah Aset Tersedia

```
1. Copy 3 file PNG ke ~/Library/Caches/HaispaceFrames/ di iPad
2. Build & run app ke iPad
3. Login sebagai Operator
4. OperatorDashboard → Diagnostics
5. Tekan "Run Platform Validation"
6. Frame Engine card harus menampilkan ✅ PASS untuk semua 7 checks
7. Screenshot hasil visual → upload ke R2 log
8. M-012 dinyatakan SELESAI
```

---

> **Dokumen ini berlaku sampai M-012 dinyatakan selesai.**
> Setelah itu, spesifikasi ini akan dipindahkan ke dokumentasi permanen di `docs/design/frame-asset-spec.md`.
