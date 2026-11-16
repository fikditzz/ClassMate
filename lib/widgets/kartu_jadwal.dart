import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/jadwal.dart';
import '../models/mata_kuliah.dart';
import '../models/perubahan_jadwal.dart';
import '../models/tugas.dart';
import 'animasi.dart';
import 'umum.dart';

/// Status satu jadwal pada hari ini: selesai, sedang berlangsung, dsb.
({String teks, JenisStatus jenis, Color strip})? statusJadwalHariIni(
  Jadwal j,
  DateTime sekarang,
) {
  if (j.hari != sekarang.weekday) return null;
  final m = sekarang.hour * 60 + sekarang.minute;
  if (m >= j.menitSelesai) {
    return (teks: 'Selesai', jenis: JenisStatus.netral, strip: Warna.garis);
  }
  if (m >= j.menitMulai) {
    return (
      teks: 'Sedang berlangsung',
      jenis: JenisStatus.sukses,
      strip: Warna.sukses,
    );
  }
  final menuju = j.menitMulai - m;
  if (menuju <= 30) {
    return (
      teks: 'Dalam $menuju mnt',
      jenis: JenisStatus.info,
      strip: Warna.primer,
    );
  }
  return (
    teks: 'Mendatang',
    jenis: JenisStatus.peringatan,
    strip: Warna.primer,
  );
}

/// Kartu untuk satu [Pertemuan]: label dan catatan menjelaskan bila
/// pertemuan diliburkan, dipindah, atau merupakan kuliah tambahan.
KartuJadwal kartuPertemuan(
  Pertemuan p, {
  Key? key,
  required String namaMataKuliah,
  MataKuliah? mataKuliah,
  bool hariIni = false,
  VoidCallback? onTap,
}) {
  final u = p.perubahan;
  String jamTujuan() => '${u?.jamMulai}–${u?.jamSelesai}';
  final (label, jenis, catatan) = switch (p.status) {
    StatusPertemuan.biasa => (null, JenisStatus.netral, null),
    StatusPertemuan.libur => (
      'Libur',
      JenisStatus.peringatan,
      'Pertemuan ini ditiadakan',
    ),
    StatusPertemuan.dipindahKeluar => (
      'Dipindah',
      JenisStatus.peringatan,
      'Dipindah ke ${formatHariTanggal(u!.tanggal!)}, ${jamTujuan()}',
    ),
    StatusPertemuan.pengganti => (
      'Pengganti',
      JenisStatus.info,
      'Pengganti pertemuan ${formatHariTanggal(u!.tanggalAsal!)}',
    ),
    StatusPertemuan.tambahan => (
      'Tambahan',
      JenisStatus.sukses,
      'Kuliah tambahan',
    ),
  };
  final keterangan = u?.keterangan ?? '';
  return KartuJadwal(
    key: key,
    jadwal: p.jadwal,
    namaMataKuliah: namaMataKuliah,
    mataKuliah: mataKuliah,
    hariIni: hariIni && p.berlangsung,
    onTap: onTap,
    label: label,
    jenisLabel: jenis,
    catatan: [?catatan, if (keterangan.isNotEmpty) keterangan].join(' • '),
    batal: !p.berlangsung,
  );
}

class KartuJadwal extends StatelessWidget {
  const KartuJadwal({
    super.key,
    required this.jadwal,
    required this.namaMataKuliah,
    this.mataKuliah,
    this.hariIni = false,
    this.onTap,
    this.label,
    this.jenisLabel = JenisStatus.netral,
    this.catatan,
    this.batal = false,
  });

  final Jadwal jadwal;
  final String namaMataKuliah;

  /// Bila ada, SKS dan dosen pengampu ikut ditampilkan.
  final MataKuliah? mataKuliah;

  /// Tampilkan status waktu (hanya bermakna untuk jadwal hari ini).
  final bool hariIni;
  final VoidCallback? onTap;

  /// Label perubahan, misalnya "Libur" atau "Tambahan".
  final String? label;
  final JenisStatus jenisLabel;
  final String? catatan;

  /// Pertemuan diliburkan atau dipindah: jam dicoret dan kartu diredupkan.
  final bool batal;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final status = hariIni && !batal
        ? statusJadwalHariIni(jadwal, DateTime.now())
        : null;
    final warnaJam = batal
        ? Warna.teksSekunder
        : switch (status?.jenis) {
            JenisStatus.sukses => Warna.sukses,
            JenisStatus.netral => Warna.teksSekunder,
            _ => Warna.primer,
          };
    final selesai = status?.jenis == JenisStatus.netral;
    final strip =
        status?.strip ??
        switch (jenisLabel) {
          _ when label == null => null,
          JenisStatus.peringatan => Warna.peringatan,
          JenisStatus.sukses => Warna.sukses,
          _ => Warna.primer,
        };
    return Kartu(
      strip: strip,
      onTap: onTap,
      // Kuliah yang sudah selesai diredupkan agar perhatian ke yang berikutnya.
      child: AnimatedOpacity(
        opacity: batal ? 0.7 : (selesai ? 0.6 : 1),
        duration: Gerak.sedang,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, size: 18, color: warnaJam),
                const SizedBox(width: 6),
                // Jam dan durasi satu paragraf: turun baris hanya bila perlu,
                // sementara chip status tetap memakai lebar alaminya.
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: '${jadwal.jamMulai} – ${jadwal.jamSelesai}',
                      style: t.labelLarge?.copyWith(
                        color: warnaJam,
                        fontFeatures: angkaTabular,
                        decoration: batal ? TextDecoration.lineThrough : null,
                      ),
                      children: [
                        TextSpan(
                          text:
                              '  ${formatLamaMenit(jadwal.menitSelesai - jadwal.menitMulai)}',
                          style: t.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (status != null)
                  ChipStatus(status.teks, jenis: status.jenis, titik: true)
                else if (label != null)
                  ChipStatus(label!, jenis: jenisLabel),
                if (onTap != null && status == null && label == null)
                  const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: Warna.teksSekunder,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(namaMataKuliah, style: t.titleMedium),
            if (catatan != null && catatan!.isNotEmpty) ...[
              const SizedBox(height: 4),
              _BarisKecil(
                ikon: batal ? Icons.event_busy_outlined : Icons.info_outline,
                teks: catatan!,
                warna: batal ? Warna.peringatanTeks : Warna.primer,
                baris: 2,
              ),
            ],
            if (mataKuliah?.dosenPengampu != null) ...[
              const SizedBox(height: 4),
              _BarisKecil(
                ikon: Icons.person_outline,
                teks: '${mataKuliah!.sks} SKS • ${mataKuliah!.dosenPengampu}',
              ),
            ],
            if (jadwal.ruang.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Warna.teksSekunder,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    jadwal.ruang,
                    style: t.bodyMedium?.copyWith(color: Warna.teksSekunder),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tenggat tugas di tampilan jadwal (strip merah).
class KartuTenggat extends StatelessWidget {
  const KartuTenggat({
    super.key,
    required this.tugas,
    required this.namaMataKuliah,
    this.onTap,
  });

  final Tugas tugas;
  final String namaMataKuliah;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Kartu(
      strip: Warna.bahaya,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, size: 16, color: Warna.bahaya),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tenggat tugas • ${formatJam(tugas.tenggat)}',
                  style: t.labelMedium?.copyWith(color: Warna.bahaya),
                ),
              ),
              ChipStatus(sisaWaktu(tugas.tenggat), jenis: JenisStatus.bahaya),
            ],
          ),
          const SizedBox(height: 8),
          Text(tugas.judul, style: t.titleMedium),
          const SizedBox(height: 2),
          Text(namaMataKuliah, style: t.bodySmall),
        ],
      ),
    );
  }
}

class _BarisKecil extends StatelessWidget {
  const _BarisKecil({
    required this.ikon,
    required this.teks,
    this.warna = Warna.teksSekunder,
    this.baris = 1,
  });

  final IconData ikon;
  final String teks;
  final Color warna;
  final int baris;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(ikon, size: 16, color: warna),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            teks,
            maxLines: baris,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: warna),
          ),
        ),
      ],
    );
  }
}
