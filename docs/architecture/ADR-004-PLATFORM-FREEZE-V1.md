# ADR-004: Platform Freeze v1.0

**Status**: Accepted (M-009B-04)
**Date**: 2026-08-01

## Context

Proyek Haispace Runtime telah melintasi fase pembentukan pondasi, dari Product Archaeology hingga Runtime Engineering. Fase saat ini, Runtime Qualification (M-009B), adalah titik validasi. Untuk mengamankan kematangan platform ini sebelum menyebar ke ekosistem yang lebih luas (macOS, visionOS, Cloud, dsb.), diperlukan sebuah mekanisme penguncian kontrak arsitektur. 

Tahap selanjutnya, M-010, tidak lagi dipandang sekadar sebagai "integrasi perangkat keras", melainkan tonggak kelahiran **Haispace Runtime Specification v1.0**.

## Decision

Kami memutuskan untuk mendefinisikan kriteria **Platform Freeze v1.0** yang akan dieksekusi tepat setelah M-009B dinyatakan selesai dengan *Evidence Package* lengkap.

Platform Freeze berarti:
1. **Constitution Frozen:** Aturan arsitektur tidak boleh dilanggar.
2. **ADR Frozen:** Keputusan desain hingga ADR ini dikunci.
3. **Capability Contracts Frozen:** Antarmuka hardware tidak boleh diubah secara sepihak.
4. **Runtime Qualification PASS:** Seluruh skenario uji di M-009B harus berstatus *Pass* dan didukung bukti (Evidence).
5. **Runtime Certificate Issued:** Sertifikat resmi v1.0 diterbitkan.
6. **Zero Critical Architecture Violations:** Tidak boleh ada kebocoran aturan arsitektur.

**Mulai saat Platform dinyatakan *FROZEN*, seluruh perubahan fundamental atau kontrak baru WAJIB melalui proses ADR baru.**

## Consequences

*   **Positif:** Haispace tidak lagi berupa produk eksperimen, melainkan platform stabil yang dapat diandalkan oleh sistem lain dalam ekosistem perusahaan.
*   **Negatif:** Penambahan fitur inti akan memakan waktu lebih lama karena harus melewati tinjauan arsitektur (ADR).
*   **M-010 Redefined:** M-010 resmi menjadi milestone peluncuran *Haispace Runtime Specification v1.0* (Platform Freeze). Integrasi hardware (kamera/printer asli) dipandang sebagai *implementasi* dari spesifikasi tersebut, bukan *penentu* dari spesifikasinya.
