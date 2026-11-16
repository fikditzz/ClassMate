import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/pengumpulan.dart';
import '../models/tugas.dart';
import '../widgets/animasi.dart';
import '../widgets/animasi_lanjut.dart';
import '../widgets/umum.dart';
import 'tugas_page.dart';

/// Membuka halaman detail tugas di atas tab yang sedang aktif.
///
/// [tagJudul] mengaktifkan animasi judul yang terbang dari kartu asal; isi
/// hanya bila kartu asal memakai JudulHero dengan tag yang sama.
void bukaDetailTugas(BuildContext context, Tugas tugas, {Object? tagJudul}) {
  final scope = AppScope.baca(context);
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          scope.bungkus(TugasDetailPage(tugas: tugas, tagJudul: tagJudul)),
    ),
  );
}

class TugasDetailPage extends StatefulWidget {
  const TugasDetailPage({super.key, required this.tugas, this.tagJudul});

  final Tugas tugas;
  final Object? tagJudul;

  @override
  State<TugasDetailPage> createState() => _TugasDetailPageState();
}

class _TugasDetailPageState extends State<TugasDetailPage> {
  late Stream<Map<String, Pengumpulan>> _milikSaya;
  late Stream<List<Pengumpulan>> _semua;

  @override
  void initState() {
    super.initState();
    final scope = AppScope.baca(context);
    _milikSaya = scope.tugas.pengumpulanSaya();
    _semua = scope.tugas.pengumpulanTugas(widget.tugas.id);
  }

  Future<void> _hapus(BuildContext context) async {
    final scope = AppScope.baca(context);
    final ya = await konfirmasi(
      context,
      ikon: Icons.delete_outline,
      judul: 'Hapus tugas ini?',
      pesan:
          '"${widget.tugas.judul}" dan semua pengumpulannya terhapus. '
          'Tindakan ini tidak bisa dibatalkan.',
      tombolYa: 'Hapus Tugas',
      bahaya: true,
    );
    if (!ya || !context.mounted) return;
    try {
      await scope.tugas.hapusTugas(widget.tugas.id);
      if (context.mounted) {
        Navigator.pop(context);
        tampilkanPesan(context, 'Tugas dihapus.');
      }
    } catch (e) {
      if (context.mounted) {
        tampilkanPesan(context, 'Gagal menghapus tugas: $e', gagal: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final tugas = widget.tugas;
    final t = Theme.of(context).textTheme;
    final lewat = tugas.sudahLewatTenggat();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Tugas'),
        actions: [
          if (scope.pengguna.isAdmin) ...[
            IconButton(
              tooltip: 'Ubah tugas',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final tersimpan = await bukaFormTugas(context, awal: tugas);
                // Daftar tugas memuat versi terbaru; detail lama ditutup.
                if (tersimpan == true && context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),
            IconButton(
              tooltip: 'Hapus tugas',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _hapus(context),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (final (i, w) in <Widget>[
            Kartu(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.school_outlined,
                        size: 16,
                        color: Warna.primer,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          scope.namaMataKuliah(tugas.mataKuliahId),
                          style: t.labelLarge?.copyWith(color: Warna.primer),
                        ),
                      ),
                      lewat
                          ? const ChipStatus(
                              'Ditutup',
                              jenis: JenisStatus.bahaya,
                            )
                          : ChipStatus(
                              'Sisa ${formatDurasi(tugas.tenggat.difference(DateTime.now()))}',
                              jenis: JenisStatus.info,
                            ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (widget.tagJudul case final tag?)
                    JudulHero(
                      tag: tag,
                      teks: tugas.judul,
                      style: t.headlineMedium,
                    )
                  else
                    Text(tugas.judul, style: t.headlineMedium),
                  const SizedBox(height: 16),
                  KotakInfo(
                    ikon: Icons.event_outlined,
                    jenis: lewat ? JenisStatus.bahaya : JenisStatus.info,
                    judul: 'TENGGAT PENGUMPULAN',
                    teks:
                        '${formatTanggalPanjang(tugas.tenggat)}, '
                        '${formatJam(tugas.tenggat)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Kartu(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        color: Warna.primer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Instruksi Pengerjaan',
                          style: t.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tugas.deskripsi.isEmpty
                        ? 'Tidak ada instruksi tambahan.'
                        : tugas.deskripsi,
                    style: t.bodyLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (scope.pengguna.isAdmin)
              _RekapPengumpulan(stream: _semua)
            else
              StreamBuilder<Map<String, Pengumpulan>>(
                stream: _milikSaya,
                builder: (context, snap) => _UnggahTugas(
                  tugas: tugas,
                  pengumpulan: snap.data?[tugas.id],
                ),
              ),
          ].indexed)
            Muncul(urutan: i, child: w),
        ],
      ),
    );
  }
}

class _UnggahTugas extends StatelessWidget {
  const _UnggahTugas({required this.tugas, this.pengumpulan});

  final Tugas tugas;
  final Pengumpulan? pengumpulan;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final lewat = tugas.sudahLewatTenggat();
    final p = pengumpulan;

    void belumTersedia() => tampilkanPesan(
      context,
      'Unggah ke Google Drive belum tersedia di versi ini.',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Kartu(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Unggah Hasil Tugas', style: t.titleMedium),
                  ),
                  // Saat tenggat lewat, status "ditutup" sudah dijelaskan oleh
                  // chip di kartu atas dan kotak info di bawah.
                  if (p != null)
                    const ChipStatus(
                      'Sudah dikumpulkan',
                      jenis: JenisStatus.sukses,
                      ikon: Icons.check_circle_outline,
                    )
                  else if (!lewat)
                    const ChipStatus(
                      'Belum terkumpul',
                      jenis: JenisStatus.peringatan,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (p != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Warna.suksesMuda,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const IkonKotak(
                        Icons.insert_drive_file_outlined,
                        jenis: JenisStatus.sukses,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.namaFile, style: t.titleSmall),
                            Text(
                              '${formatUkuran(p.ukuran)} • ${formatTenggat(p.waktuUpload)}',
                              style: t.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else if (lewat)
                const KotakInfo(
                  jenis: JenisStatus.bahaya,
                  ikon: Icons.lock_outline,
                  judul: 'Pengumpulan ditutup',
                  teks: 'Tenggat sudah lewat. Hubungi admin kelas bila perlu perpanjangan.',
                )
              else
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: belumTersedia,
                  child: KotakPutusPutus(
                    child: Column(
                      children: [
                        const IkonKotak(
                          Icons.cloud_upload_outlined,
                          ukuran: 56,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Pilih berkas untuk diunggah',
                          style: t.titleSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Berkas disimpan di Google Drive milikmu',
                          style: t.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Wrap(
                          spacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            ChipStatus('PDF', jenis: JenisStatus.info),
                            ChipStatus('ZIP', jenis: JenisStatus.info),
                            ChipStatus(
                              'Maks. 20 MB',
                              jenis: JenisStatus.netral,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!lewat)
          FilledButton.icon(
            onPressed: belumTersedia,
            icon: Icon(p == null ? Icons.folder_open : Icons.swap_horiz),
            label: Text(p == null ? 'Pilih Berkas Tugas' : 'Ganti Berkas'),
          ),
      ],
    );
  }
}

class _RekapPengumpulan extends StatelessWidget {
  const _RekapPengumpulan({required this.stream});

  final Stream<List<Pengumpulan>> stream;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return StreamBuilder<List<Pengumpulan>>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData) return const KartuKerangka();
        final daftar = [...snap.data!]
          ..sort((a, b) => b.waktuUpload.compareTo(a.waktuUpload));
        return Kartu(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Rekap Pengumpulan', style: t.titleMedium),
                    ),
                    ChipStatus(
                      '${daftar.length} terkumpul',
                      jenis: daftar.isEmpty
                          ? JenisStatus.netral
                          : JenisStatus.sukses,
                    ),
                  ],
                ),
              ),
              if (daftar.isEmpty)
                const KeadaanKosong(
                  ikon: Icons.inbox_outlined,
                  judul: 'Belum ada yang mengumpulkan',
                  pesan: 'Pengumpulan anggota akan muncul di sini secara langsung.',
                  ringkas: true,
                )
              else
                for (final (i, p) in daftar.indexed) ...[
                  if (i > 0) const Divider(indent: 72),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: AvatarInisial(p.email),
                    title: Text(p.email, style: t.titleSmall),
                    subtitle: Text(
                      '${p.namaFile} • ${formatUkuran(p.ukuran)}',
                      style: t.bodySmall,
                    ),
                    trailing: Text(
                      formatTenggat(p.waktuUpload),
                      style: t.bodySmall,
                    ),
                  ),
                ],
            ],
          ),
        );
      },
    );
  }
}
