import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_scope.dart';
import '../core/errors.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/kas.dart';
import '../repositories/kas_repository.dart';
import '../widgets/animasi.dart';
import '../widgets/animasi_lanjut.dart';
import '../widgets/umum.dart';

/// Membuka halaman Uang Kas di atas tab yang sedang aktif.
Future<void> bukaKas(BuildContext context) {
  final scope = AppScope.baca(context);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => scope.bungkus(const KasPage())),
  );
}

enum _FilterKas { semua, masuk, keluar }

enum _TampilanAdmin { riwayat, iuran }

/// Data halaman kas yang dimuat sekaligus.
class _DataKas {
  const _DataKas({
    required this.ringkasan,
    required this.riwayat,
    this.iuranSaya = const [],
    this.statusIuran = const [],
  });

  final RingkasanKas ringkasan;
  final List<TransaksiKas> riwayat;
  final List<TransaksiKas> iuranSaya;
  final List<StatusIuran> statusIuran;
}

class KasPage extends StatefulWidget {
  const KasPage({super.key});

  @override
  State<KasPage> createState() => _KasPageState();
}

class _KasPageState extends State<KasPage> {
  late Future<_DataKas> _data;
  var _filter = _FilterKas.semua;
  var _tampilan = _TampilanAdmin.riwayat;

  KasRepository get _repo => AppScope.baca(context).kas;
  bool get _admin => AppScope.baca(context).pengguna.bolehKelolaAkun;

  @override
  void initState() {
    super.initState();
    _data = _muat();
  }

  Future<_DataKas> _muat() async {
    final admin = _admin;
    final hasil = await Future.wait<Object>([
      _repo.ringkasan(),
      _repo.riwayatKelas(),
      admin ? _repo.statusIuran() : _repo.iuranSaya(),
    ]);
    return _DataKas(
      ringkasan: hasil[0] as RingkasanKas,
      riwayat: hasil[1] as List<TransaksiKas>,
      iuranSaya: admin ? const [] : hasil[2] as List<TransaksiKas>,
      statusIuran: admin ? hasil[2] as List<StatusIuran> : const [],
    );
  }

  Future<void> _segarkan() async {
    final baru = _muat();
    setState(() => _data = baru);
    await baru.catchError(
      (_) => const _DataKas(
        ringkasan: RingkasanKas(saldo: 0, masukBulanIni: 0, keluarBulanIni: 0),
        riwayat: [],
      ),
    );
  }

  Future<void> _catat(_DataKas data, {TransaksiKas? awal}) async {
    final scope = AppScope.baca(context);
    final disimpan = await bukaLembar<bool>(
      context,
      judul: (awal?.id ?? '').isEmpty
          ? 'Catat Transaksi Kas'
          : 'Ubah Transaksi',
      subjudul: 'Semua anggota bisa melihat saldo dan pengeluaran kelas.',
      isi: (_) => _FormKas(
        repo: scope.kas,
        anggota: data.statusIuran,
        aturan: data.ringkasan.aturan,
        awal: awal,
      ),
    );
    if (disimpan == true && mounted) {
      tampilkanPesan(context, 'Transaksi tersimpan.');
      _segarkan();
    }
  }

  Future<void> _aturIuran(AturanIuran? sekarang) async {
    final scope = AppScope.baca(context);
    final disimpan = await bukaLembar<bool>(
      context,
      judul: 'Aturan Iuran Mingguan',
      subjudul: 'Dipakai untuk menghitung tunggakan setiap anggota.',
      isi: (_) => _FormAturan(repo: scope.kas, awal: sekarang),
    );
    if (disimpan == true && mounted) {
      tampilkanPesan(context, 'Aturan iuran tersimpan.');
      _segarkan();
    }
  }

  Future<void> _detail(TransaksiKas t, _DataKas data) async {
    final t2 = Theme.of(context).textTheme;
    final aksi = await bukaLembar<String>(
      context,
      judul: t.judul,
      subjudul: formatTanggalPanjang(t.tanggal),
      isi: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ChipStatus(t.jenis.label, jenis: _jenisStatus(t.jenis)),
              const Spacer(),
              Text(
                formatRupiahBertanda(t.nilai),
                style: t2.headlineSmall?.copyWith(color: _warna(t.jenis)),
              ),
            ],
          ),
          if (t.namaAnggota != null) ...[
            const SizedBox(height: 12),
            KotakInfo(
              ikon: Icons.person_outline,
              judul: 'Dibayar oleh',
              teks: t.namaAnggota!,
            ),
          ],
          if (_admin && t.id.isNotEmpty) ...[
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.pop(ctx, 'ubah'),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Ubah Transaksi'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Warna.bahaya),
              onPressed: () => Navigator.pop(ctx, 'hapus'),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Hapus Transaksi'),
            ),
          ],
        ],
      ),
    );
    if (!mounted) return;
    if (aksi == 'ubah') {
      await _catat(data, awal: t);
    } else if (aksi == 'hapus') {
      final ya = await konfirmasi(
        context,
        ikon: Icons.delete_outline,
        judul: 'Hapus transaksi ini?',
        pesan: 'Saldo kas kelas akan dihitung ulang tanpa transaksi ini.',
        tombolYa: 'Hapus',
        bahaya: true,
      );
      if (!ya || !mounted) return;
      try {
        await _repo.hapus(t.id);
        if (mounted) tampilkanPesan(context, 'Transaksi dihapus.');
        _segarkan();
      } on ClassMateException catch (e) {
        if (mounted) tampilkanPesan(context, e.pesan, gagal: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = AppScope.of(context).pengguna.bolehKelolaAkun;
    return FutureBuilder<_DataKas>(
      future: _data,
      builder: (context, snap) {
        final data = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Uang Kas'),
            actions: [
              if (admin && data != null)
                IconButton(
                  tooltip: 'Aturan iuran',
                  onPressed: () => _aturIuran(data.ringkasan.aturan),
                  icon: const Icon(Icons.tune),
                ),
            ],
          ),
          floatingActionButton: admin && data != null
              ? FloatingActionButton.extended(
                  onPressed: () => _catat(data),
                  icon: const Icon(Icons.add),
                  label: const Text('Catat Transaksi'),
                )
              : null,
          body: RefreshIndicator(
            onRefresh: _segarkan,
            child: _isi(snap, admin),
          ),
        );
      },
    );
  }

  Widget _isi(AsyncSnapshot<_DataKas> snap, bool admin) {
    if (snap.hasError) {
      final pesan = snap.error is ClassMateException
          ? (snap.error! as ClassMateException).pesan
          : '${snap.error}';
      return ListView(
        children: [
          KeadaanKosong(
            ikon: Icons.cloud_off_outlined,
            judul: 'Uang kas belum bisa dimuat',
            pesan: pesan,
            aksi: OutlinedButton.icon(
              onPressed: _segarkan,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ),
        ],
      );
    }
    final data = snap.data;
    if (data == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          KartuKerangka(),
          SizedBox(height: 16),
          KartuKerangka(),
        ],
      );
    }

    final riwayat = data.riwayat
        .where(
          (t) => switch (_filter) {
            _FilterKas.semua => true,
            _FilterKas.masuk => t.jenis.masuk,
            _FilterKas.keluar => !t.jenis.masuk,
          },
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Muncul(child: _KartuSaldo(ringkasan: data.ringkasan)),
        const SizedBox(height: 16),
        if (!admin)
          Muncul(
            urutan: 1,
            child: _KartuIuranSaya(
              aturan: data.ringkasan.aturan,
              iuran: data.iuranSaya,
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<_TampilanAdmin>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _TampilanAdmin.riwayat,
                  icon: Icon(Icons.receipt_long_outlined),
                  label: Text('Riwayat'),
                ),
                ButtonSegment(
                  value: _TampilanAdmin.iuran,
                  icon: Icon(Icons.groups_outlined),
                  label: Text('Status Iuran'),
                ),
              ],
              selected: {_tampilan},
              onSelectionChanged: (s) => setState(() => _tampilan = s.first),
            ),
          ),
        if (admin && _tampilan == _TampilanAdmin.iuran)
          ..._statusIuran(data)
        else ...[
          JudulBagian('Riwayat Kas Kelas', atas: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in _FilterKas.values) ...[
                  ChoiceChip(
                    label: Text(switch (f) {
                      _FilterKas.semua => 'Semua',
                      _FilterKas.masuk => 'Pemasukan',
                      _FilterKas.keluar => 'Pengeluaran',
                    }),
                    selected: _filter == f,
                    showCheckmark: false,
                    selectedColor: Warna.primerMuda,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (riwayat.isEmpty)
            Kartu(
              child: KeadaanKosong(
                ikon: Icons.savings_outlined,
                judul: data.riwayat.isEmpty
                    ? 'Belum ada transaksi'
                    : 'Tidak ada transaksi di filter ini',
                pesan: data.riwayat.isEmpty
                    ? (admin
                          ? 'Tekan "Catat Transaksi" untuk mencatat iuran '
                                'atau pengeluaran pertama.'
                          : 'Riwayat kas kelas akan tampil di sini.')
                    : null,
                ringkas: true,
              ),
            )
          else
            ..._daftarPerBulan(riwayat, data),
        ],
      ],
    );
  }

  List<Widget> _daftarPerBulan(List<TransaksiKas> daftar, _DataKas data) {
    final hasil = <Widget>[];
    String? bulan;
    var i = 0;
    for (final t in daftar) {
      final b = formatBulanTahun(t.tanggal);
      if (b != bulan) {
        bulan = b;
        final isi = daftar.where((x) => formatBulanTahun(x.tanggal) == b);
        final total = isi.fold<int>(0, (s, x) => s + x.nilai);
        hasil.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Row(
              children: [
                Expanded(child: LabelAtas(b, warna: Warna.teksSekunder)),
                Text(
                  formatRupiahBertanda(total),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: total < 0 ? Warna.bahaya : Warna.sukses,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      hasil.add(
        Muncul(
          key: ValueKey('${_filter.name}-${t.id}-${t.tanggal}-${t.jumlah}'),
          urutan: i++,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _BarisTransaksi(
              t: t,
              tampilkanNama: _admin,
              onTap: () => _detail(t, data),
            ),
          ),
        ),
      );
    }
    return hasil;
  }

  List<Widget> _statusIuran(_DataKas data) {
    final aturan = data.ringkasan.aturan;
    final t = Theme.of(context).textTheme;
    final menunggak = data.statusIuran
        .where((s) => s.tunggakan(aturan) > 0)
        .length;
    return [
      const SizedBox(height: 16),
      if (aturan == null)
        KotakInfo(
          jenis: JenisStatus.peringatan,
          ikon: Icons.tune,
          judul: 'Aturan iuran belum diatur',
          teks:
              'Atur nominal iuran mingguan agar tunggakan tiap anggota bisa '
              'dihitung.',
          trailing: TextButton(
            onPressed: () => _aturIuran(null),
            child: const Text('Atur'),
          ),
        )
      else
        KotakInfo(
          ikon: Icons.event_repeat,
          judul:
              '${formatRupiah(aturan.nominal)} per pekan • '
              'pekan ke-${aturan.pekanBerjalan()}',
          teks: menunggak == 0
              ? 'Semua anggota sudah lunas.'
              : '$menunggak anggota masih punya tunggakan.',
        ),
      const SizedBox(height: 12),
      if (data.statusIuran.isEmpty)
        const Kartu(
          child: KeadaanKosong(
            ikon: Icons.groups_outlined,
            judul: 'Belum ada anggota',
            ringkas: true,
          ),
        )
      else
        Kartu(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, s) in data.statusIuran.indexed) ...[
                if (i > 0) const Divider(indent: 68),
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                  leading: AvatarInisial(s.nama),
                  title: Text(s.nama, style: t.titleSmall),
                  subtitle: Text(
                    '${s.kaliBayar}× bayar • ${formatRupiah(s.totalBayar)}',
                    style: t.bodySmall,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (aturan != null)
                        s.tunggakan(aturan) > 0
                            ? ChipStatus(
                                '−${formatRupiah(s.tunggakan(aturan))}',
                                jenis: JenisStatus.bahaya,
                              )
                            : const ChipStatus(
                                'Lunas',
                                jenis: JenisStatus.sukses,
                                ikon: Icons.check_circle_outline,
                              ),
                      IconButton(
                        tooltip: 'Catat iuran ${s.nama}',
                        onPressed: () => _catat(
                          data,
                          awal: TransaksiKas(
                            jenis: JenisKas.iuran,
                            jumlah: aturan?.nominal ?? 0,
                            tanggal: DateTime.now(),
                            userId: s.userId,
                          ),
                        ),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
    ];
  }
}

JenisStatus _jenisStatus(JenisKas j) => switch (j) {
  JenisKas.iuran => JenisStatus.info,
  JenisKas.pemasukan => JenisStatus.sukses,
  JenisKas.pengeluaran => JenisStatus.bahaya,
};

Color _warna(JenisKas j) => j.masuk ? Warna.sukses : Warna.bahaya;

IconData _ikon(JenisKas j) => switch (j) {
  JenisKas.iuran => Icons.savings_outlined,
  JenisKas.pemasukan => Icons.south_west,
  JenisKas.pengeluaran => Icons.north_east,
};

/// Kartu saldo bergradasi dengan arus kas bulan ini.
class _KartuSaldo extends StatelessWidget {
  const _KartuSaldo({required this.ringkasan});

  final RingkasanKas ringkasan;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final masuk = ringkasan.masukBulanIni;
    final keluar = ringkasan.keluarBulanIni;
    final total = masuk + keluar;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1AA7B2), Color(0xFF0A6670)],
        ),
        boxShadow: Bayangan.elev2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'SALDO KAS KELAS',
                style: t.labelSmall?.copyWith(
                  color: Colors.white70,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RupiahBerjalan(
            ringkasan.saldo,
            format: formatRupiah,
            style: t.displaySmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ArusKas(
                  ikon: Icons.south_west,
                  label: 'Masuk bulan ini',
                  nilai: masuk,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ArusKas(
                  ikon: Icons.north_east,
                  label: 'Keluar bulan ini',
                  nilai: keluar,
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 14),
            // Perbandingan masuk dan keluar bulan ini.
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: masuk / total),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  color: const Color(0xFF8BF1EC),
                  backgroundColor: const Color(0x66FFB4AB),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ArusKas extends StatelessWidget {
  const _ArusKas({
    required this.ikon,
    required this.label,
    required this.nilai,
  });

  final IconData ikon;
  final String label;
  final int nilai;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelSmall?.copyWith(color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          RupiahBerjalan(
            nilai,
            format: formatRupiah,
            style: t.titleMedium?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Status iuran pengguna sendiri (desain 9a).
class _KartuIuranSaya extends StatelessWidget {
  const _KartuIuranSaya({required this.aturan, required this.iuran});

  final AturanIuran? aturan;
  final List<TransaksiKas> iuran;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = AppScope.of(context).pengguna;
    final status = StatusIuran(
      userId: p.uid,
      nama: p.nama,
      totalBayar: iuran.fold(0, (s, x) => s + x.jumlah),
      kaliBayar: iuran.length,
    );
    final tunggakan = status.tunggakan(aturan);
    final pekan = aturan?.pekanBerjalan() ?? 0;
    final lunas = status.pekanLunas(aturan);
    return Kartu(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AvatarInisial(p.nama, ukuran: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Iuran Saya', style: t.titleMedium),
                    Text(
                      aturan == null
                          ? 'Aturan iuran belum diatur admin'
                          : '${formatRupiah(aturan!.nominal)} per pekan',
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
              if (aturan != null)
                tunggakan > 0
                    ? const ChipStatus(
                        'Ada tunggakan',
                        jenis: JenisStatus.bahaya,
                      )
                    : const ChipStatus(
                        'Lunas',
                        jenis: JenisStatus.sukses,
                        ikon: Icons.check_circle_outline,
                      ),
            ],
          ),
          if (aturan != null && pekan > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text('Progres pekan', style: t.labelLarge)),
                Text(
                  '${lunas.clamp(0, pekan)} / $pekan pekan',
                  style: t.labelLarge?.copyWith(color: Warna.primer),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (lunas / pekan).clamp(0, 1)),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) =>
                    LinearProgressIndicator(value: v, minHeight: 8),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Angka(
                  ikon: Icons.check_circle_outline,
                  label: 'Terbayar',
                  nilai: formatRupiah(status.totalBayar),
                  warna: Warna.sukses,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Angka(
                  ikon: Icons.error_outline,
                  label: 'Tunggakan',
                  nilai: formatRupiah(tunggakan),
                  warna: tunggakan > 0 ? Warna.bahaya : Warna.teksSekunder,
                ),
              ),
            ],
          ),
          if (iuran.isNotEmpty) ...[
            const Divider(height: 28),
            Text('Riwayat iuran terakhir', style: t.labelLarge),
            const SizedBox(height: 4),
            for (final x in iuran.take(3))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_outlined,
                      size: 18,
                      color: Warna.teksSekunder,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            x.keterangan.isEmpty ? 'Iuran kas' : x.keterangan,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyMedium,
                          ),
                          Text(
                            formatTanggalSingkat(x.tanggal),
                            style: t.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      formatRupiah(x.jumlah),
                      style: t.labelLarge?.copyWith(color: Warna.sukses),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Angka extends StatelessWidget {
  const _Angka({
    required this.ikon,
    required this.label,
    required this.nilai,
    required this.warna,
  });

  final IconData ikon;
  final String label;
  final String nilai;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Warna.latar,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(ikon, size: 18, color: warna),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.bodySmall),
                Text(nilai, style: t.titleSmall?.copyWith(color: warna)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarisTransaksi extends StatelessWidget {
  const _BarisTransaksi({
    required this.t,
    required this.tampilkanNama,
    required this.onTap,
  });

  final TransaksiKas t;
  final bool tampilkanNama;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final sub = [
      formatTanggalSingkat(t.tanggal),
      if (tampilkanNama && t.namaAnggota != null) t.namaAnggota!,
      // Baris iuran gabungan sudah menyebut "Iuran" di judulnya.
      if ((!tampilkanNama || t.namaAnggota == null) && !t.gabungan)
        t.jenis.label,
    ].join(' • ');
    return Kartu(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          IkonKotak(_ikon(t.jenis), jenis: _jenisStatus(t.jenis), ukuran: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.judul,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(sub, style: tt.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatRupiahBertanda(t.nilai),
            style: tt.labelLarge?.copyWith(
              color: _warna(t.jenis),
              fontFeatures: angkaTabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// Form catat/ubah transaksi (desain 9c).
class _FormKas extends StatefulWidget {
  const _FormKas({
    required this.repo,
    required this.anggota,
    required this.aturan,
    this.awal,
  });

  final KasRepository repo;
  final List<StatusIuran> anggota;
  final AturanIuran? aturan;
  final TransaksiKas? awal;

  @override
  State<_FormKas> createState() => _FormKasState();
}

class _FormKasState extends State<_FormKas> {
  late JenisKas _jenis = widget.awal?.jenis ?? JenisKas.iuran;
  late String? _anggota = widget.awal?.userId;
  late DateTime _tanggal = widget.awal?.tanggal ?? DateTime.now();
  late final _nominal = TextEditingController(
    text: (widget.awal?.jumlah ?? widget.aturan?.nominal ?? 0) > 0
        ? '${widget.awal?.jumlah ?? widget.aturan?.nominal}'
        : '',
  );
  late final _keterangan = TextEditingController(
    text: widget.awal?.keterangan ?? '',
  );
  bool _memproses = false;
  String? _galat;

  static const _cepat = [5000, 10000, 20000, 50000];

  @override
  void dispose() {
    _nominal.dispose();
    _keterangan.dispose();
    super.dispose();
  }

  int get _jumlah => int.tryParse(_nominal.text.replaceAll('.', '')) ?? 0;

  void _tambah(int n) {
    HapticFeedback.selectionClick();
    setState(() => _nominal.text = '${_jumlah + n}');
  }

  Future<void> _simpan() async {
    setState(() {
      _memproses = true;
      _galat = null;
    });
    try {
      await widget.repo.simpan(
        TransaksiKas(
          id: widget.awal?.id ?? '',
          jenis: _jenis,
          jumlah: _jumlah,
          tanggal: _tanggal,
          keterangan: _keterangan.text,
          userId: _jenis == JenisKas.iuran ? _anggota : null,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on ClassMateException catch (e) {
      if (mounted) {
        setState(() {
          _memproses = false;
          _galat = e.pesan;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<JenisKas>(
          showSelectedIcon: false,
          segments: [
            for (final j in JenisKas.values)
              ButtonSegment(value: j, label: Text(j.label)),
          ],
          selected: {_jenis},
          onSelectionChanged: (s) => setState(() => _jenis = s.first),
        ),
        const SizedBox(height: 16),
        AnimatedSize(
          duration: Gerak.sedang,
          curve: Gerak.kurva,
          child: _jenis == JenisKas.iuran
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String>(
                    initialValue: _anggota,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Anggota yang membayar',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    items: [
                      for (final a in widget.anggota)
                        DropdownMenuItem(value: a.userId, child: Text(a.nama)),
                    ],
                    onChanged: (v) => setState(() => _anggota = v),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        TextField(
          controller: _nominal,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: t.headlineSmall?.copyWith(fontFeatures: angkaTabular),
          decoration: InputDecoration(
            labelText: 'Nominal',
            prefixText: 'Rp ',
            helperText: _jumlah > 0 ? formatRupiah(_jumlah) : null,
            suffixIcon: _nominal.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Kosongkan',
                    onPressed: () => setState(_nominal.clear),
                    icon: const Icon(Icons.cancel_outlined),
                  ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final n in _cepat)
              ActionChip(
                label: Text('+${n ~/ 1000}rb'),
                onPressed: () => _tambah(n),
              ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            final pilih = await showDatePicker(
              context: context,
              initialDate: _tanggal,
              firstDate: DateTime(DateTime.now().year - 2),
              lastDate: DateTime.now().add(const Duration(days: 1)),
            );
            if (pilih != null) setState(() => _tanggal = pilih);
          },
          icon: const Icon(Icons.event_outlined),
          label: Text(formatTanggalPanjang(_tanggal)),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _keterangan,
          maxLength: 120,
          decoration: InputDecoration(
            labelText: _jenis == JenisKas.pengeluaran
                ? 'Keperluan (wajib diisi agar transparan)'
                : 'Keterangan',
            hintText: _jenis == JenisKas.iuran
                ? 'Misalnya: Iuran pekan 9'
                : 'Misalnya: Print modul praktikum',
          ),
        ),
        if (_galat != null) ...[
          const SizedBox(height: 4),
          KotakInfo(
            jenis: JenisStatus.bahaya,
            ikon: Icons.error_outline,
            teks: _galat!,
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed:
              _memproses ||
                  _jumlah <= 0 ||
                  (_jenis == JenisKas.iuran && _anggota == null) ||
                  (_jenis == JenisKas.pengeluaran &&
                      _keterangan.text.trim().isEmpty)
              ? null
              : _simpan,
          icon: const Icon(Icons.save_outlined),
          label: Text(_memproses ? 'Menyimpan…' : 'Simpan Transaksi'),
        ),
      ],
    );
  }
}

class _FormAturan extends StatefulWidget {
  const _FormAturan({required this.repo, this.awal});

  final KasRepository repo;
  final AturanIuran? awal;

  @override
  State<_FormAturan> createState() => _FormAturanState();
}

class _FormAturanState extends State<_FormAturan> {
  late final _nominal = TextEditingController(
    text: '${widget.awal?.nominal ?? 10000}',
  );
  late DateTime _mulai = widget.awal?.mulai ?? _seninIni();
  bool _memproses = false;

  static DateTime _seninIni() {
    final n = DateTime.now();
    final h = DateTime(n.year, n.month, n.day);
    return h.subtract(Duration(days: h.weekday - 1));
  }

  @override
  void dispose() {
    _nominal.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    setState(() => _memproses = true);
    try {
      await widget.repo.aturIuran(
        AturanIuran(nominal: int.tryParse(_nominal.text) ?? 0, mulai: _mulai),
      );
      if (mounted) Navigator.pop(context, true);
    } on ClassMateException catch (e) {
      if (mounted) {
        setState(() => _memproses = false);
        tampilkanPesan(context, e.pesan, gagal: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final aturan = AturanIuran(
      nominal: int.tryParse(_nominal.text) ?? 0,
      mulai: _mulai,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nominal,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Nominal per pekan',
            prefixText: 'Rp ',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            final pilih = await showDatePicker(
              context: context,
              initialDate: _mulai,
              firstDate: DateTime(DateTime.now().year - 2),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (pilih != null) setState(() => _mulai = pilih);
          },
          icon: const Icon(Icons.event_outlined),
          label: Text('Mulai ${formatTanggalPanjang(_mulai)}'),
        ),
        const SizedBox(height: 16),
        KotakInfo(
          ikon: Icons.calculate_outlined,
          teks: aturan.pekanBerjalan() == 0
              ? 'Iuran belum dimulai.'
              : 'Sekarang pekan ke-${aturan.pekanBerjalan()}: target tiap '
                    'anggota ${formatRupiah(aturan.target())}.',
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _memproses || aturan.nominal <= 0 ? null : _simpan,
          child: Text(_memproses ? 'Menyimpan…' : 'Simpan Aturan'),
        ),
      ],
    );
  }
}
