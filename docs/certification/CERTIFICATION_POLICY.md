# CERTIFICATION POLICY
# Haispace Enterprise Platform

Kebijakan ini mengatur penerbitan *Runtime Certificate*.

## Syarat Penerbitan Sertifikat (Resolution M-009B-01)
**Sebuah Runtime Certificate tidak boleh diterbitkan hanya karena semua checklist dicentang.** Certificate hanya sah apabila dilampirkan bersama sebuah **Evidence Package**.

Minimal *evidence* yang wajib ada:
1. `Qualification Checklist` (M-009B)
2. `Timeline Log` (Ekspor `RuntimeTimelineLogger`)
3. `Health Snapshot` (Output `HealthAggregator`)
4. `Session Audit Trail`
5. `Scenario Results` (Bukti eksekusi tiap skenario dari `ScenarioEngine`)
6. `Runtime Readiness Score`

### Setiap Scenario Menghasilkan Bukti (Resolution M-009B-02)
Setiap eksekusi skenario kegagalan wajib menghasilkan artefak:
* Timeline Events (kapan kegagalan terjadi)
* Health Transition (penurunan skor kesehatan)
* Workflow Transition (apakah UI masuk ke layar *error*)
* Recovery Duration (waktu yang dibutuhkan hingga pulih)

### Runtime Readiness Measurement (Resolution M-009B-03)
Readiness Score tidak boleh menjadi angka statis tunggal. Skor harus dipilah berdasarkan domain untuk memperlihatkan kelemahan sistem secara presisi:
* Boot (Contoh: 100%)
* Workflow (Contoh: 100%)
* Hardware (Contoh: 95%)
* Observability (Contoh: 100%)
* Recovery (Contoh: 98%)
* **Overall Score (Rata-rata tertimbang)**
Sertifikat dianggap **tidak berlaku (revoked)** jika:
1. Terjadi perubahan pada *Platform Constitution* yang tidak divalidasi ulang.
2. Ditemukan *bug* fatal (Severity: P0) pada *production* yang menyebabkan *downtime* > 1 jam.
3. Struktur *Hardware Capability* (Printer/Camera) mengalami perombakan drastis.

Setiap *Major Release* (misal v1.0 ke v2.0) **wajib** memiliki *Certificate* baru.
