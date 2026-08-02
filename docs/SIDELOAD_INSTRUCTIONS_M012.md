# Instruksi Sideload & Device Validation M-012

M-012 Frame Engine telah mengadopsi standar **Asset Package v1** (menggunakan `template.json`).
Karena fitur sinkronisasi dari Cloud (I-001) belum dibangun, Anda perlu men-*sideload* aset dummy secara manual ke dalam iPad / Simulator untuk melakukan validasi.

## 1. Lokasi Dummy Assets
Skrip telah men-generate 3 folder *mock* yang mensimulasikan ekstraksi dari file `.hspasset`:
- `haispace-runtime-ios/docs/dummy_assets/mock-single` (1 slot)
- `haispace-runtime-ios/docs/dummy_assets/mock-strip` (3 slot vertikal)
- `haispace-runtime-ios/docs/dummy_assets/mock-grid` (4 slot grid)

## 2. Cara Sideload ke iPad / Simulator

Anda bebas meletakkan folder tersebut di lokasi yang bisa dijangkau oleh `CoreImageEditingRuntime`.
Rekomendasi untuk pengetesan:
1. Pindahkan ketiga folder tersebut ke dalam direktori Documents aplikasi (melalui Finder/Files app) atau masukkan ke dalam *App Bundle* untuk sementara.
2. Pastikan `EditingConfiguration.frame.assetPath` menunjuk ke path **folder** tersebut secara langsung. 
   *(Contoh: `.../Documents/mock-strip`)*
3. Runtime otomatis akan mencari `template.json` dan `frame.png` di dalam folder tersebut.

## 3. Langkah Validasi

1. **Jalankan Aplikasi** di iPad (atau Simulator jika tidak ada perangkat).
2. **Lakukan pengambilan foto** menggunakan antarmuka M-010.
3. (Atau gunakan `FrameEngineValidator` jika tersedia UI-nya).
4. **Verifikasi Visual:**
   - **Single:** Foto menempati 1 area besar di tengah.
   - **Strip:** Foto yang sama (atau berbeda jika implementasi foto-berbeda sudah ada) diulang sebanyak 3 kali dari atas ke bawah.
   - **Grid:** Foto yang sama diulang 4 kali dalam pola grid 2x2.
   - Ada hiasan teks "Haispace - mock-..." di bagian pojok kiri atas.

## 4. Kriteria Kelulusan (M-012 Closure)
Jika ketiga frame mock tersebut berhasil dirender tanpa *crash* dan ukuran kanvas / slot sesuai (*fit-to-fill* tanpa distorsi rasio aspek), maka M-012 resmi dinyatakan **SELESAI** dan *frozen*.
