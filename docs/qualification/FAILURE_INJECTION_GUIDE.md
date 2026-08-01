# FAILURE INJECTION GUIDE
# Haispace Enterprise Platform — Qualification

Panduan ini digunakan oleh QA / Operator untuk menguji fitur *Failure Injection* via *Scenario Engine* di *Mission Control* (khusus `#if DEBUG`).

## Cara Menggunakan

1. Jalankan aplikasi di perangkat fisik atau simulator.
2. Buka **Mission Control** > tab **Kualifikasi**.
3. Di panel **Scenario Execution**, pilih skenario yang ingin diuji.
4. Klik **Run**.
5. Amati perilaku sistem (apakah *recover* otomatis atau membatalkan sesi dengan rapi).

## Skenario Tersedia

### 1. Printer Offline (`printerOffline`)
- **Tujuan:** Menguji apakah aplikasi bisa menangani hilangnya koneksi printer.
- **Ekspektasi:** UI menampilkan peringatan printer. Cetak akan ditangguhkan hingga printer kembali online atau dibatalkan oleh operator.

### 2. Camera Disconnect During Capture (`cameraDisconnectDuringCapture`)
- **Tujuan:** Menguji hilangnya umpan kamera saat sedang *live preview* atau pengambilan gambar.
- **Ekspektasi:** Sesi aktif dibatalkan secara aman, atau sistem memberikan opsi *retry*. Aplikasi tidak boleh *crash*.

### 3. Network Lost During Upload (`networkLostDuringUpload`)
- **Tujuan:** Menguji ketahanan *upload queue* ketika koneksi terputus.
- **Ekspektasi:** *Upload* ditunda. Saat koneksi dipulihkan, *upload* otomatis dilanjutkan (tidak ada data hilang).
