// Bagian beranda untuk fitur pengumuman, uang kas, dan rekap kehadiran.
import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/kas.dart';
import '../models/pengguna.dart';
import '../models/pengumuman.dart';
import '../models/rekap_kehadiran.dart';
import '../pages/kas_page.dart';
import '../pages/pengumuman_page.dart';
import '../pages/rekap_kehadiran_page.dart';
import 'animasi_lanjut.dart';
import 'umum.dart';

/// Membuka tab atau halaman untuk satu menu pintasan.
Future<void> bukaMenu(BuildContext context, MenuItem m) async {
  switch (m) {
    case MenuItem.kas:
      await bukaKas(context);
    case MenuItem.pengumuman:
      await bukaPengumuman(context);
    case MenuItem.kehadiran:
      await bukaRekapKehadiran(context);
    default:
      AppScope.baca(context).bukaTab(m.tab);
  }
}

/// Grid tiga kolom menu pintasan (polimorfik: isi sesuai peran).
class GridAksesPintas extends StatelessWidget {
  const GridAksesPintas({super.key, required this.menu, this.onKembali});

  final List<MenuItem> menu;

  /// Dipanggil setelah halaman yang dibuka dari menu ditutup.
  final VoidCallback? onKembali;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const kolom = 3, jarak = 8.0;
        final lebar = (c.maxWidth - jarak * (kolom - 1)) / kolom;
        return Wrap(
          spacing: jarak,
          runSpacing: jarak,
          children: [
            for (final m in menu)
              SizedBox(
                width: lebar,
                child: Kartu(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 4,
                  ),
                  onTap: () async {
                    await bukaMenu(context, m);
                    if (m.tab < 0) onKembali?.call();
                  },
                  child: Column(
                    children: [
                      IkonKotak(m.ikon, ukuran: 44),
                      const SizedBox(height: 8),
                      Text(
                        m.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Pengumuman terbaru (yang penting didahulukan bila masih baru).
class KartuPengumumanTerbaru extends StatelessWidget {
  const KartuPengumumanTerbaru({
    super.key,
    required this.daftar,
    this.onKembali,
  });

  final Future<List<Pengumuman>> daftar;
  final VoidCallback? onKembali;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return FutureBuilder<List<Pengumuman>>(
      future: daftar,
      builder: (context, snap) {
        final semua = snap.data ?? const <Pengumuman>[];
        if (semua.isEmpty) return const SizedBox.shrink();
        final sekarang = DateTime.now();
        final p = semua.firstWhere(
          (x) =>
              x.penting &&
              sekarang.difference(x.dibuatPada) < const Duration(days: 7),
          orElse: () => semua.first,
        );
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Kartu(
            strip: p.penting ? Warna.bahaya : Warna.primer,
            onTap: () async {
              await bukaPengumuman(context);
              onKembali?.call();
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.campaign_outlined,
                      size: 18,
                      color: p.penting ? Warna.bahaya : Warna.primer,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: LabelAtas(
                        p.penting ? 'Pengumuman penting' : 'Pengumuman',
                        warna: p.penting ? Warna.bahaya : Warna.primer,
                      ),
                    ),
                    Text(formatRelatif(p.dibuatPada), style: t.bodySmall),
                  ],
                ),
                const SizedBox(height: 8),
                Text(p.judul, style: t.titleMedium),
                if (p.isi.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    p.isi,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium?.copyWith(color: Warna.teksSekunder),
                  ),
                ],
                if (semua.length > 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Lihat ${semua.length - 1} pengumuman lainnya',
                    style: t.labelMedium?.copyWith(color: Warna.primer),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Dua kartu statistik singkat: kehadiran (anggota) dan saldo kas.
class StatistikBeranda extends StatelessWidget {
  const StatistikBeranda({
    super.key,
    required this.kehadiran,
    required this.kas,
    this.onKembali,
  });

  /// Null bila pengguna tidak punya rekap kehadiran (admin/dosen).
  final Future<RekapKehadiran>? kehadiran;

  /// Null bila pengguna tidak melihat uang kas (dosen).
  final Future<RingkasanKas>? kas;
  final VoidCallback? onKembali;

  @override
  Widget build(BuildContext context) {
    final kartu = <Widget>[
      if (kehadiran case final f?)
        FutureBuilder<RekapKehadiran>(
          future: f,
          builder: (context, snap) {
            final persen = snap.data?.persen;
            final jenis = persen == null
                ? JenisStatus.netral
                : jenisKehadiran(persen);
            return _KartuAngka(
              ikon: Icons.insights_outlined,
              label: 'Kehadiran',
              jenis: jenis,
              isi: persen == null
                  ? Text(
                      snap.hasError ? '—' : (snap.hasData ? 'Belum ada' : '…'),
                      style: _gayaAngka(context, jenis),
                    )
                  : CincinPersen(
                      nilai: persen,
                      warna: jenis.depan,
                      latar: jenis.latar,
                      ukuran: 54,
                      tebal: 6,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: jenis.depan),
                    ),
              keterangan: snap.data == null || persen == null
                  ? 'Rekap per mata kuliah'
                  : '${snap.data!.hadir}/${snap.data!.totalSesi} sesi',
              onTap: () async {
                await bukaRekapKehadiran(context);
                onKembali?.call();
              },
            );
          },
        ),
      if (kas case final f?)
        FutureBuilder<RingkasanKas>(
          future: f,
          builder: (context, snap) {
            final r = snap.data;
            return _KartuAngka(
              ikon: Icons.account_balance_wallet_outlined,
              label: 'Kas Kelas',
              jenis: JenisStatus.info,
              isi: r == null
                  ? Text(
                      snap.hasError ? '—' : '…',
                      style: _gayaAngka(context, JenisStatus.info),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: RupiahBerjalan(
                        r.saldo,
                        format: formatRupiah,
                        style: _gayaAngka(context, JenisStatus.info),
                      ),
                    ),
              keterangan: r == null
                  ? 'Saldo dan iuran'
                  : 'Bulan ini ${formatRupiahBertanda(r.selisihBulanIni)}',
              onTap: () async {
                await bukaKas(context);
                onKembali?.call();
              },
            );
          },
        ),
    ];
    if (kartu.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, k) in kartu.indexed) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: k),
            ],
          ],
        ),
      ),
    );
  }

  static TextStyle? _gayaAngka(BuildContext context, JenisStatus j) =>
      Theme.of(context).textTheme.headlineSmall?.copyWith(color: j.depan);
}

class _KartuAngka extends StatelessWidget {
  const _KartuAngka({
    required this.ikon,
    required this.label,
    required this.jenis,
    required this.isi,
    required this.keterangan,
    required this.onTap,
  });

  final IconData ikon;
  final String label;
  final JenisStatus jenis;
  final Widget isi;
  final String keterangan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Kartu(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, size: 18, color: jenis.depan),
              const SizedBox(width: 6),
              Expanded(child: Text(label, style: t.labelLarge)),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: Warna.teksSekunder,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 54,
            child: Align(alignment: Alignment.centerLeft, child: isi),
          ),
          const SizedBox(height: 8),
          Text(
            keterangan,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}
