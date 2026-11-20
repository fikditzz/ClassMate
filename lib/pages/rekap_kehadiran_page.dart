import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/errors.dart';
import '../core/theme.dart';
import '../models/rekap_kehadiran.dart';
import '../widgets/animasi.dart';
import '../widgets/animasi_lanjut.dart';
import '../widgets/umum.dart';

/// Batas kehadiran yang ditandai: di bawah ini mata kuliah diberi peringatan.
const batasKehadiran = 0.75;

/// Membuka halaman Rekap Kehadiran di atas tab yang sedang aktif.
Future<void> bukaRekapKehadiran(BuildContext context) {
  final scope = AppScope.baca(context);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => scope.bungkus(const RekapKehadiranPage()),
    ),
  );
}

/// Warna sesuai persentase kehadiran.
JenisStatus jenisKehadiran(double persen) => persen >= 0.9
    ? JenisStatus.sukses
    : persen >= batasKehadiran
    ? JenisStatus.info
    : JenisStatus.bahaya;

class RekapKehadiranPage extends StatefulWidget {
  const RekapKehadiranPage({super.key});

  @override
  State<RekapKehadiranPage> createState() => _RekapKehadiranPageState();
}

class _RekapKehadiranPageState extends State<RekapKehadiranPage> {
  late Future<RekapKehadiran> _rekap;

  @override
  void initState() {
    super.initState();
    _rekap = AppScope.baca(context).absensi.rekapKehadiranSaya();
  }

  Future<void> _segarkan() async {
    final baru = AppScope.baca(context).absensi.rekapKehadiranSaya();
    setState(() => _rekap = baru);
    try {
      await baru;
    } catch (_) {
      // Galat ditampilkan oleh FutureBuilder.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Rekap Kehadiran')),
      body: RefreshIndicator(
        onRefresh: _segarkan,
        child: FutureBuilder<RekapKehadiran>(
          future: _rekap,
          builder: (context, snap) {
            if (snap.hasError) {
              final e = snap.error;
              return ListView(
                children: [
                  KeadaanKosong(
                    ikon: Icons.cloud_off_outlined,
                    judul: 'Rekap belum bisa dimuat',
                    pesan: e is ClassMateException ? e.pesan : '$e',
                  ),
                ],
              );
            }
            final rekap = snap.data;
            if (rekap == null) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: const [KartuKerangka()],
              );
            }
            final persen = rekap.persen;
            if (persen == null) {
              return ListView(
                children: const [
                  KeadaanKosong(
                    ikon: Icons.insights_outlined,
                    judul: 'Belum ada sesi absensi',
                    pesan:
                        'Rekap muncul setelah dosen atau ketua kelas membuka '
                        'sesi absen.',
                  ),
                ],
              );
            }
            final jenis = jenisKehadiran(persen);
            final rawan = rekap.perMataKuliah
                .where((r) => r.persen < batasKehadiran)
                .length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Muncul(
                  child: Kartu(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CincinPersen(
                          nilai: persen,
                          warna: jenis.depan,
                          latar: jenis.latar,
                          style: t.headlineSmall?.copyWith(color: jenis.depan),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const LabelAtas('Total kehadiran'),
                              const SizedBox(height: 4),
                              Text(
                                '${rekap.hadir} dari ${rekap.totalSesi} sesi',
                                style: t.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${rekap.totalSesi - rekap.hadir}× tidak hadir • '
                                '${rekap.perMataKuliah.length} mata kuliah',
                                style: t.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (rawan > 0)
                  KotakInfo(
                    jenis: JenisStatus.bahaya,
                    ikon: Icons.warning_amber_rounded,
                    judul: '$rawan mata kuliah di bawah 75%',
                    teks:
                        'Perhatikan kehadiran di mata kuliah yang ditandai '
                        'merah.',
                  )
                else
                  const KotakInfo(
                    jenis: JenisStatus.sukses,
                    ikon: Icons.verified_outlined,
                    teks: 'Semua mata kuliah di atas 75%. Pertahankan!',
                  ),
                JudulBagian('Per mata kuliah', atas: 20),
                for (final (i, r) in rekap.perMataKuliah.indexed) ...[
                  Muncul(
                    urutan: i + 1,
                    child: _BarisMk(
                      nama: scope.namaMataKuliah(r.mataKuliahId),
                      rekap: r,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BarisMk extends StatelessWidget {
  const _BarisMk({required this.nama, required this.rekap});

  final String nama;
  final RekapKehadiranMk rekap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final jenis = jenisKehadiran(rekap.persen);
    return Kartu(
      strip: rekap.persen < batasKehadiran ? Warna.bahaya : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(nama, style: t.titleSmall)),
              const SizedBox(width: 8),
              ChipStatus('${(rekap.persen * 100).round()}%', jenis: jenis),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: rekap.persen),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                color: jenis.depan,
                backgroundColor: jenis.latar,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hadir ${rekap.hadir} dari ${rekap.totalSesi} sesi'
            '${rekap.absen > 0 ? ' • ${rekap.absen}× tidak hadir' : ''}',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}
