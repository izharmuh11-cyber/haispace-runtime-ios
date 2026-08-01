# CERTIFICATION POLICY
# Haispace Enterprise Platform

Kebijakan ini mengatur penerbitan *Runtime Certificate*.

## Syarat Penerbitan Sertifikat
1. **Green Build:** *Source code* harus lulus CI tanpa *error* atau *warning* kritikal.
2. **100% Core Pass:** Seluruh kriteria pada bagian BOOT dan SESSION di `RUNTIME_ACCEPTANCE_PROTOCOL` harus hijau (`PASS`).
3. **Recovery Resilience:** Minimal 80% dari skenario Recovery harus `PASS`.
4. **Observability Confirmed:** Seluruh aliran data telemetri harus tervalidasi `PASS`.
5. **No Critical Leaks:** Bagian PERFORMANCE tidak boleh memiliki indikasi kebocoran memori (memory leak) atau *actor deadlock*.

## Pencabutan (Revocation)
Sertifikat dianggap **tidak berlaku (revoked)** jika:
1. Terjadi perubahan pada *Platform Constitution* yang tidak divalidasi ulang.
2. Ditemukan *bug* fatal (Severity: P0) pada *production* yang menyebabkan *downtime* > 1 jam.
3. Struktur *Hardware Capability* (Printer/Camera) mengalami perombakan drastis.

Setiap *Major Release* (misal v1.0 ke v2.0) **wajib** memiliki *Certificate* baru.
