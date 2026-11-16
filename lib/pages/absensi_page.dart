import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_scope.dart';
import '../core/errors.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/kehadiran.dart';
import '../models/sesi_absensi.dart';
import '../repositories/absensi_repository.dart';
import '../widgets/animasi.dart';
import '../widgets/animasi_lanjut.dart';
import '../widgets/umum.dart';

class AbsensiPage extends StatefulWidget {
  const AbsensiPage({super.key});

  @override
  State<AbsensiPage> createState() => _AbsensiPageState();
}

class _AbsensiPageState extends State<AbsensiPage> {
  late Stream<List<SesiAbsensi>> _sesi;
  late Stream<Set<String>> _sudahHadir;

  /// Sesi yang baru saja berhasil diabsen (menampilkan layar sukses).
  ({SesiAbsensi sesi, DateTime waktu})? _berhasil;

  @override
  void initState() {
    super.initState();
    final scope = AppScope.baca(context);
    _sesi = scope.absensi.sesiAktif();
    _sudahHadir = scope.absensi.sesiYangSudahDihadiri();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final admin = scope.pengguna.isAdmin;

    return Scaffold(
      appBar: appBarClassMate(
        context,
        judul: admin ? 'Absensi' : 'Presensi Kelas',
      ),
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => bukaLembar<void>(
                context,
                judul: 'Buat Sesi Presensi',
                subjudul: 'Token 6 karakter dibuat otomatis untuk dibagikan di kelas.',
                isi: (_) => _FormSesi(scope: scope),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Buat Sesi'),
            )
          : null,
      // StreamBuilder selalu terpasang: stream Firestore tidak boleh
      // didengarkan ulang setelah layar sukses ditutup.
      body: StreamBuilder<Set<String>>(
        stream: _sudahHadir,
        builder: (context, hadirSnap) => StreamBuilder<List<SesiAbsensi>>(
          stream: _sesi,
          builder: (context, snap) {
            if (_berhasil != null) {
              return _LayarBerhasil(
                sesi: _berhasil!.sesi,
                waktu: _berhasil!.waktu,
                onSelesai: () {
                  setState(() => _berhasil = null);
                  scope.bukaTab(0);
                },
              );
            }
            if (snap.hasError) {
              return KeadaanKosong(
                ikon: Icons.error_outline,
                judul: 'Gagal memuat sesi',
                pesan: '${snap.error}',
              );
            }
            if (!snap.hasData) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: const [KartuKerangka()],
              );
            }
            final daftar = snap.data!;
            if (daftar.isEmpty) {
              return Center(
                child: KeadaanKosong(
                  ikon: Icons.event_available_outlined,
                  judul: 'Tidak ada sesi presensi aktif',
                  pesan: admin
                      ? 'Tekan "Buat Sesi" saat kuliah dimulai untuk membuat token.'
                      : 'Sesi akan muncul di sini saat admin kelas membukanya.',
                ),
              );
            }
            final hadir = hadirSnap.data ?? const <String>{};
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: daftar.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, i) {
                final s = daftar[i];
                return Muncul(
                  key: ValueKey('m${s.id}'),
                  urutan: i,
                  child: admin
                      ? _PanelSesiAdmin(key: ValueKey(s.id), sesi: s)
                      : _PanelSesiAnggota(
                          key: ValueKey(s.id),
                          sesi: s,
                          sudahHadir: hadir.contains(s.id),
                          onBerhasil: (w) =>
                              setState(() => _berhasil = (sesi: s, waktu: w)),
                        ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Anggota
// ---------------------------------------------------------------------------

class _KepalaSesi extends StatelessWidget {
  const _KepalaSesi({required this.sesi, required this.status});

  final SesiAbsensi sesi;
  final Widget status;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                scope.namaMataKuliah(sesi.mataKuliahId),
                style: t.headlineSmall,
              ),
            ),
            const SizedBox(width: 8),
            status,
          ],
        ),
        if (scope.mataKuliahDari(sesi.mataKuliahId)?.dosenPengampu
            case final dosen?) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 16,
                color: Warna.teksSekunder,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  dosen,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium?.copyWith(color: Warna.teksSekunder),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Petak(
                ikon: Icons.schedule,
                teks: '${formatJam(sesi.mulai)} - ${formatJam(sesi.berakhir)}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Petak(
                ikon: Icons.calendar_today_outlined,
                teks: formatHariTanggal(sesi.mulai),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Petak extends StatelessWidget {
  const _Petak({required this.ikon, required this.teks});

  final IconData ikon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Warna.latar,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Warna.garis),
      ),
      child: Row(
        children: [
          Icon(ikon, size: 18, color: Warna.primer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              teks,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Warna.teks),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kotak "Batas presensi sesi" dengan hitung mundur dan bilah sisa waktu.
class _BatasWaktu extends StatelessWidget {
  const _BatasWaktu({required this.sesi});

  final SesiAbsensi sesi;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final total = sesi.berakhir
        .difference(sesi.mulai)
        .inSeconds
        .clamp(1, 1 << 31);
    return HitungMundur(
      batas: sesi.berakhir,
      builder: (context, sisa) {
        final habis = sisa.isNegative;
        final warna = habis
            ? Warna.bahaya
            : sisa.inMinutes < 3
            ? Warna.peringatanTeks
            : Warna.primer;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: habis ? Warna.bahayaMuda : Warna.primerMuda,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 18, color: warna),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'BATAS PRESENSI SESI',
                      style: t.labelMedium?.copyWith(
                        color: warna,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    formatHitungMundur(sisa),
                    style: t.headlineSmall?.copyWith(
                      color: warna,
                      fontWeight: FontWeight.w700,
                      fontFeatures: angkaTabular,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                // Nilai berubah tiap detik; tween membuat bilah turun mulus.
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: habis ? 0 : sisa.inSeconds / total),
                  duration: const Duration(seconds: 1),
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    color: warna,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PanelSesiAnggota extends StatefulWidget {
  const _PanelSesiAnggota({
    super.key,
    required this.sesi,
    required this.sudahHadir,
    required this.onBerhasil,
  });

  final SesiAbsensi sesi;
  final bool sudahHadir;
  final ValueChanged<DateTime> onBerhasil;

  @override
  State<_PanelSesiAnggota> createState() => _PanelSesiAnggotaState();
}

class _PanelSesiAnggotaState extends State<_PanelSesiAnggota> {
  final _token = TextEditingController();
  bool _memproses = false;
  String? _galat;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    if (_memproses) return;
    if (_token.text.length < InputToken.panjang) {
      setState(() => _galat = 'Token terdiri dari 6 karakter.');
      return;
    }
    if (!widget.sesi.masihBerlaku()) {
      setState(
        () => _galat =
            'Token sudah kedaluwarsa. Waktu presensi sesi ini telah habis.',
      );
      return;
    }
    setState(() {
      _memproses = true;
      _galat = null;
    });
    try {
      await AppScope.baca(context).absensi.hadir(widget.sesi.id, _token.text);
      HapticFeedback.mediumImpact();
      if (mounted) widget.onBerhasil(DateTime.now());
    } on ClassMateException catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _galat = e.pesan);
    } finally {
      if (mounted) setState(() => _memproses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = AppScope.of(context).pengguna;
    final berlaku = widget.sesi.masihBerlaku();

    final status = widget.sudahHadir
        ? const ChipStatus(
            'Hadir',
            jenis: JenisStatus.sukses,
            ikon: Icons.check_circle_outline,
          )
        : berlaku
        ? const ChipStatus('Dibuka', jenis: JenisStatus.sukses, titik: true)
        : const ChipStatus('Kedaluwarsa', jenis: JenisStatus.netral);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Kartu(
          strip: widget.sudahHadir
              ? Warna.sukses
              : berlaku
              ? Warna.primer
              : Warna.garis,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _KepalaSesi(sesi: widget.sesi, status: status),
              // Hitung mundur hanya selagi sesi berjalan; status lain sudah
              // dijelaskan oleh chip dan kartu info di bawah.
              if (!widget.sudahHadir && berlaku) ...[
                const SizedBox(height: 12),
                _BatasWaktu(sesi: widget.sesi),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (widget.sudahHadir)
          const Kartu(
            child: KotakInfo(
              jenis: JenisStatus.sukses,
              ikon: Icons.verified_outlined,
              judul: 'Kamu sudah absen di sesi ini',
              teks: 'Kehadiranmu sudah tercatat dan tidak perlu dikirim ulang.',
            ),
          )
        else if (!berlaku)
          const Kartu(
            child: KotakInfo(
              jenis: JenisStatus.bahaya,
              ikon: Icons.timer_off_outlined,
              judul: 'Token kedaluwarsa',
              teks:
                  'Waktu presensi sesi ini sudah habis. Hubungi admin kelas bila '
                  'kamu hadir tetapi belum tercatat.',
            ),
          )
        else
          Kartu(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Masukkan 6 Digit Token Presensi',
                  textAlign: TextAlign.center,
                  style: t.titleMedium,
                ),
                const SizedBox(height: 16),
                InputToken(
                  controller: _token,
                  aktif: !_memproses,
                  galat: _galat != null,
                  onSelesai: _kirim,
                ),
                if (_galat != null) ...[
                  const SizedBox(height: 12),
                  KotakInfo(
                    jenis: JenisStatus.bahaya,
                    ikon: Icons.error_outline,
                    teks: _galat!,
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _memproses ? null : _kirim,
                  icon: _memproses
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.how_to_reg),
                  label: Text(_memproses ? 'Memproses…' : 'Kirim Presensi'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    AvatarInisial(p.nama, ukuran: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.nama, style: t.titleSmall),
                          Text('@${p.username}', style: t.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Presensi hanya dapat dikirim sekali dan langsung tercatat permanen.',
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Layar "Presensi Berhasil Dicatat!" (desain 3b).
class _LayarBerhasil extends StatelessWidget {
  const _LayarBerhasil({
    required this.sesi,
    required this.waktu,
    required this.onSelesai,
  });

  final SesiAbsensi sesi;
  final DateTime waktu;
  final VoidCallback onSelesai;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Kartu(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: Column(
            children: [
              MunculMemantul(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: Warna.suksesMuda,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  // Lingkaran menyapu lalu centang tergambar.
                  child: const CentangDigambar(ukuran: 56, warna: Warna.sukses),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Presensi Berhasil Dicatat!',
                textAlign: TextAlign.center,
                style: t.headlineSmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Kartu(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: LabelAtas('Mata kuliah')),
                  const ChipStatus(
                    'Hadir',
                    jenis: JenisStatus.sukses,
                    titik: true,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                scope.namaMataKuliah(sesi.mataKuliahId),
                style: t.titleLarge,
              ),
              const Divider(height: 24),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _Ringkasan(
                        ikon: Icons.schedule,
                        judul: 'Waktu presensi',
                        isi: formatJam(waktu),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: _Ringkasan(
                        ikon: Icons.pin_outlined,
                        judul: 'Metode',
                        isi: 'Token kelas',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onSelesai,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Kembali ke Beranda'),
        ),
      ],
    );
  }
}

class _Ringkasan extends StatelessWidget {
  const _Ringkasan({
    required this.ikon,
    required this.judul,
    required this.isi,
  });

  final IconData ikon;
  final String judul;
  final String isi;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Warna.primerMuda,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, size: 16, color: Warna.primer),
              const SizedBox(width: 6),
              Flexible(child: Text(judul, style: t.bodySmall)),
            ],
          ),
          const SizedBox(height: 6),
          Text(isi, style: t.titleLarge),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Admin
// ---------------------------------------------------------------------------

class _PanelSesiAdmin extends StatefulWidget {
  const _PanelSesiAdmin({super.key, required this.sesi});

  final SesiAbsensi sesi;

  @override
  State<_PanelSesiAdmin> createState() => _PanelSesiAdminState();
}

class _PanelSesiAdminState extends State<_PanelSesiAdmin> {
  late Future<String> _token;
  late Stream<List<Kehadiran>> _rekap;

  @override
  void initState() {
    super.initState();
    final repo = AppScope.baca(context).absensi;
    _token = repo.tokenSesi(widget.sesi.id);
    _rekap = repo.rekapSesi(widget.sesi.id);
  }

  Future<void> _tutup() async {
    final ya = await konfirmasi(
      context,
      ikon: Icons.lock_outline,
      judul: 'Tutup sesi presensi?',
      pesan: 'Anggota tidak bisa absen lagi setelah sesi ditutup.',
      tombolYa: 'Tutup Sesi',
      bahaya: true,
    );
    if (!ya || !mounted) return;
    await AppScope.baca(context).absensi.tutupSesi(widget.sesi.id);
    if (mounted) tampilkanPesan(context, 'Sesi presensi ditutup.');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final berlaku = widget.sesi.masihBerlaku();

    return StreamBuilder<List<Kehadiran>>(
      stream: _rekap,
      builder: (context, snap) {
        final hadir = [...?snap.data]
          ..sort((a, b) => b.waktuAbsen.compareTo(a.waktuAbsen));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Kartu(
              warna: Warna.primerMuda,
              bayangan: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _KepalaSesi(
                    sesi: widget.sesi,
                    status: berlaku
                        ? const ChipStatus(
                            'Berlangsung',
                            jenis: JenisStatus.sukses,
                            titik: true,
                          )
                        : const ChipStatus(
                            'Waktu habis',
                            jenis: JenisStatus.netral,
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Kartu(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: ChipStatus(
                      'KODE TOKEN PRESENSI',
                      jenis: JenisStatus.info,
                      ikon: Icons.pin_outlined,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<String>(
                    future: _token,
                    builder: (context, tokenSnap) {
                      final token = tokenSnap.data ?? '······';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              color: Warna.primerMuda,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SelectableText(
                                token.split('').join(' '),
                                style: t.displaySmall?.copyWith(
                                  fontSize: 40,
                                  letterSpacing: 6,
                                  color: Warna.teks,
                                  fontFeatures: angkaTabular,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  onPressed: tokenSnap.hasData
                                      ? () {
                                          Clipboard.setData(
                                            ClipboardData(text: token),
                                          );
                                          tampilkanPesan(
                                            context,
                                            'Token disalin.',
                                          );
                                        }
                                      : null,
                                  icon: const Icon(Icons.copy_outlined),
                                  label: const Text('Salin Token'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  onPressed: () => _bukaRekap(context, hadir),
                                  icon: const Icon(Icons.fact_check_outlined),
                                  label: const Text('Rekap'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  if (berlaku) ...[
                    const SizedBox(height: 12),
                    _BatasWaktu(sesi: widget.sesi),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Kartu(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Warna.sukses,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Kehadiran', style: t.titleMedium)),
                      // Saat kosong, keterangan di bawah sudah cukup.
                      if (hadir.isNotEmpty)
                        ChipStatus(
                          '${hadir.length} hadir',
                          jenis: JenisStatus.sukses,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (hadir.isEmpty)
                    Text('Belum ada anggota yang absen.', style: t.bodySmall)
                  else ...[
                    for (final k in hadir.take(3)) ...[
                      _BarisKehadiran(k),
                      const SizedBox(height: 8),
                    ],
                    // Daftar lengkap ada di tombol "Rekap" di atas.
                    if (hadir.length > 3)
                      Text(
                        '+${hadir.length - 3} anggota lainnya hadir',
                        style: t.bodySmall,
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Warna.bahaya),
              onPressed: _tutup,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Tutup Sesi Presensi Sekarang'),
            ),
          ],
        );
      },
    );
  }

  void _bukaRekap(BuildContext context, List<Kehadiran> hadir) {
    final scope = AppScope.baca(context);
    bukaLembar<void>(
      context,
      judul: 'Rekap Kehadiran',
      subjudul:
          '${scope.namaMataKuliah(widget.sesi.mataKuliahId)} • '
          '${hadir.length} anggota hadir',
      isi: (_) => hadir.isEmpty
          ? const KeadaanKosong(
              ikon: Icons.groups_outlined,
              judul: 'Belum ada yang absen',
              ringkas: true,
            )
          : Column(
              children: [
                for (final k in hadir) ...[
                  _BarisKehadiran(k),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }
}

class _BarisKehadiran extends StatelessWidget {
  const _BarisKehadiran(this.k);

  final Kehadiran k;

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
          AvatarInisial(k.email, ukuran: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  k.email,
                  style: t.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('${formatJam(k.waktuAbsen)} WIB', style: t.bodySmall),
              ],
            ),
          ),
          const ChipStatus(
            'Valid',
            jenis: JenisStatus.sukses,
            ikon: Icons.check_circle_outline,
          ),
        ],
      ),
    );
  }
}

class _FormSesi extends StatefulWidget {
  const _FormSesi({required this.scope});

  final AppScope scope;

  @override
  State<_FormSesi> createState() => _FormSesiState();
}

class _FormSesiState extends State<_FormSesi> {
  String? _mk;
  int _durasi = 15;
  bool _memproses = false;

  AbsensiRepository get _repo => widget.scope.absensi;

  @override
  Widget build(BuildContext context) {
    final mk = widget.scope.mataKuliah;
    if (mk.isEmpty) {
      return const KeadaanKosong(
        ikon: Icons.menu_book_outlined,
        judul: 'Belum ada mata kuliah',
        pesan: 'Tambahkan di Profil → Kelola mata kuliah.',
        ringkas: true,
      );
    }
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _mk,
          decoration: const InputDecoration(labelText: 'Mata kuliah'),
          items: [
            for (final m in mk)
              DropdownMenuItem(value: m.id, child: Text(m.nama)),
          ],
          onChanged: (v) => setState(() => _mk = v),
        ),
        const SizedBox(height: 20),
        Text('Durasi sesi', style: t.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 10, label: Text('10 mnt')),
            ButtonSegment(value: 15, label: Text('15 mnt')),
            ButtonSegment(value: 30, label: Text('30 mnt')),
            ButtonSegment(value: 60, label: Text('60 mnt')),
          ],
          selected: {_durasi},
          onSelectionChanged: (s) => setState(() => _durasi = s.first),
        ),
        const SizedBox(height: 16),
        KotakInfo(
          ikon: Icons.info_outline,
          teks:
              'Sesi dibuka sekarang dan ditutup otomatis pukul '
              '${formatJam(DateTime.now().add(Duration(minutes: _durasi)))}.',
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _mk == null || _memproses ? null : _simpan,
          icon: const Icon(Icons.key_outlined),
          label: Text(_memproses ? 'Membuat…' : 'Buka Sesi & Buat Token'),
        ),
      ],
    );
  }

  Future<void> _simpan() async {
    setState(() => _memproses = true);
    try {
      final mulai = DateTime.now();
      await _repo.buatSesi(
        mataKuliahId: _mk!,
        mulai: mulai,
        berakhir: mulai.add(Duration(minutes: _durasi)),
      );
      if (mounted) {
        Navigator.pop(context);
        tampilkanPesan(context, 'Sesi dibuka. Bagikan token di kelas.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _memproses = false);
        tampilkanPesan(context, 'Gagal membuat sesi: $e', gagal: true);
      }
    }
  }
}
