import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/jadwal.dart';
import '../models/kas.dart';
import '../models/pengguna.dart';
import '../models/pengumuman.dart';
import '../models/pengumpulan.dart';
import '../models/perubahan_jadwal.dart';
import '../models/rekap_kehadiran.dart';
import '../models/sesi_absensi.dart';
import '../models/tugas.dart';
import '../widgets/animasi.dart';
import '../widgets/beranda_tambahan.dart';
import '../widgets/kartu_jadwal.dart';
import '../widgets/umum.dart';
import 'tugas_detail_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Stream<List<Jadwal>> _jadwal;
  late Stream<List<PerubahanJadwal>> _perubahan;
  late Stream<List<SesiAbsensi>> _sesi;
  late Stream<List<Tugas>> _tugas;
  late Stream<Map<String, Pengumpulan>> _kumpul;

  /// Membangun ulang tiap menit agar status waktu tetap akurat.
  final Stream<void> _detak = Stream<void>.periodic(const Duration(minutes: 1));

  @override
  void initState() {
    super.initState();
    final scope = AppScope.baca(context);
    _jadwal = scope.jadwal.semuaJadwal();
    _perubahan = scope.jadwal.perubahanJadwal();
    _sesi = scope.absensi.sesiAktif();
    _tugas = scope.tugas.daftarTugas();
    _kumpul = scope.tugas.pengumpulanSaya();
    _muatTambahan();
  }

  late Future<List<Pengumuman>> _pengumuman;
  Future<RingkasanKas>? _kas;
  Future<RekapKehadiran>? _kehadiran;

  /// Pengumuman, kas, dan kehadiran tidak realtime; dimuat ulang saat
  /// kembali dari halamannya. Galat ditelan agar beranda tetap tampil.
  void _muatTambahan() {
    final scope = AppScope.baca(context);
    final p = scope.pengguna;
    _pengumuman = scope.pengumuman.daftar().catchError(
      (Object _) => const <Pengumuman>[],
    );
    _kas = p.menuUtama.contains(MenuItem.kas) ? scope.kas.ringkasan() : null;
    _kehadiran = p.menuUtama.contains(MenuItem.kehadiran)
        ? scope.absensi.rekapKehadiranSaya()
        : null;
  }

  void _segarkanTambahan() {
    if (!mounted) return;
    setState(_muatTambahan);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = scope.pengguna;

    return Scaffold(
      appBar: appBarClassMate(
        context,
        logo: true,
        labelAtas: null,
        judul: 'ClassMate',
        subjudul: p.isAdmin ? 'Beranda Admin Kelas' : 'Beranda Mahasiswa',
      ),
      body: StreamBuilder<void>(
        stream: _detak,
        builder: (context, _) => StreamBuilder<List<Jadwal>>(
          // Satu langganan jadwal dipakai bersama oleh kartu presensi dan
          // bagian jadwal (stream Firestore hanya boleh didengar sekali).
          stream: _jadwal,
          builder: (context, jadwalSnap) => StreamBuilder<List<PerubahanJadwal>>(
            stream: _perubahan,
            builder: (context, ubahSnap) => StreamBuilder<List<SesiAbsensi>>(
              stream: _sesi,
              builder: (context, sesiSnap) {
                final aktif = (sesiSnap.data ?? const <SesiAbsensi>[])
                    .where((s) => s.masihBerlaku())
                    .toList();
                // Jadwal hari ini setelah libur, pindahan, dan kuliah tambahan.
                final hariIni = jadwalSnap.hasData
                    ? pertemuanPada(
                        DateTime.now(),
                        jadwalSnap.data!,
                        ubahSnap.data ?? const [],
                      )
                    : null;
                // Column (bukan ListView) agar bagian yang tergulir keluar
                // layar tidak dibuang lalu dibangun ulang: StreamBuilder di
                // dalamnya akan mendengarkan stream yang sama dua kali.
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    // Bagian-bagian beranda masuk bertahap dari atas ke bawah.
                    children: [
                      for (final (i, w) in <Widget>[
                        _KartuSapaan(),
                        KartuPengumumanTerbaru(
                          daftar: _pengumuman,
                          onKembali: _segarkanTambahan,
                        ),
                        const SizedBox(height: 16),
                        _KartuPresensi(
                          memuat: !sesiSnap.hasData,
                          aktif: aktif,
                          hariIni: hariIni ?? const [],
                        ),
                        StatistikBeranda(
                          kehadiran: _kehadiran,
                          kas: _kas,
                          onKembali: _segarkanTambahan,
                        ),
                        JudulBagian('Akses Pintas'),
                        GridAksesPintas(
                          menu: p.menuUtama,
                          onKembali: _segarkanTambahan,
                        ),
                        _BagianJadwal(pertemuan: hariIni),
                        _BagianTenggat(tugas: _tugas, kumpul: _kumpul),
                      ].indexed)
                        Muncul(urutan: i, child: w),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _KartuSapaan extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).pengguna;
    final t = Theme.of(context).textTheme;
    return Kartu(
      child: Row(
        children: [
          AvatarInisial(p.nama, ukuran: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tanggal ikut di baris sapaan, jadi tidak perlu baris status
                // terpisah di atas kartu.
                Text(
                  '${_sapaan(DateTime.now().hour)} • '
                  '${formatHariTanggal(DateTime.now())}',
                  style: t.bodySmall,
                ),
                Text(
                  p.nama,
                  style: t.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '@${p.username}${p.kelasId == null ? '' : ' • ${p.kelasId}'}',
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
          // Peran sudah tertulis di subjudul header; di sini cukup penanda
          // mode demo bila aktif.
          if (AppScope.of(context).modeDemo)
            const ChipStatus('Demo', jenis: JenisStatus.peringatan),
        ],
      ),
    );
  }
}

/// Kartu besar status presensi: sesi yang dibuka, atau kuliah berikutnya.
class _KartuPresensi extends StatelessWidget {
  const _KartuPresensi({
    required this.memuat,
    required this.aktif,
    required this.hariIni,
  });

  final bool memuat;
  final List<SesiAbsensi> aktif;
  final List<Pertemuan> hariIni;

  @override
  Widget build(BuildContext context) {
    if (memuat) return const KartuKerangka();
    final scope = AppScope.of(context);
    final t = Theme.of(context).textTheme;

    if (aktif.isNotEmpty) {
      final s = aktif.first;
      return Kartu(
        warna: Warna.primerMuda,
        bayangan: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IkonKotak(Icons.how_to_reg, jenis: JenisStatus.sukses),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sesi Presensi Dibuka', style: t.titleMedium),
                      Text(
                        scope.namaMataKuliah(s.mataKuliahId),
                        style: t.bodyMedium?.copyWith(
                          color: Warna.teksSekunder,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: Warna.primer),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ditutup ${formatJam(s.berakhir)} • ${sisaWaktu(s.berakhir)}',
                    style: t.bodySmall?.copyWith(color: Warna.primer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => scope.bukaTab(1),
              icon: Icon(
                scope.pengguna.isAdmin ? Icons.key_outlined : Icons.how_to_reg,
              ),
              label: Text(
                scope.pengguna.isAdmin ? 'Lihat Token Sesi' : 'Absen Sekarang',
              ),
            ),
          ],
        ),
      );
    }

    // Tidak ada sesi: tampilkan kuliah berikutnya hari ini.
    final now = DateTime.now();
    final m = now.hour * 60 + now.minute;
    final berikut = hariIni
        .where((p) => p.berlangsung && p.jadwal.menitMulai > m)
        .firstOrNull
        ?.jadwal;
    return Kartu(
      warna: Warna.primerMuda,
      bayangan: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IkonKotak(Icons.free_breakfast_outlined, ukuran: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tidak Ada Sesi Presensi Aktif',
                  style: t.titleMedium,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: Warna.teksSekunder),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  berikut == null
                      ? 'Tidak ada kuliah lagi hari ini'
                      : 'Kuliah berikutnya: ${scope.namaMataKuliah(berikut.mataKuliahId)} (${berikut.jamMulai})',
                  style: t.bodyMedium?.copyWith(color: Warna.teksSekunder),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BagianJadwal extends StatelessWidget {
  const _BagianJadwal({required this.pertemuan});

  /// Pertemuan hari ini; `null` selama masih dimuat.
  final List<Pertemuan>? pertemuan;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final daftar = pertemuan ?? const <Pertemuan>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JudulBagian(
          'Jadwal Kuliah Hari Ini',
          aksi: 'Semua',
          onAksi: () => scope.bukaTab(3),
        ),
        if (pertemuan == null)
          const KartuKerangka()
        else if (daftar.isEmpty)
          const Kartu(
            child: KeadaanKosong(
              ikon: Icons.weekend_outlined,
              judul: 'Tidak ada kuliah hari ini',
              pesan: 'Manfaatkan waktunya untuk mencicil tugas.',
              ringkas: true,
            ),
          )
        else
          // Pertemuan yang libur atau dipindah tetap ditampilkan (diredupkan)
          // agar anggota tahu jadwalnya berubah.
          for (final p in daftar)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: kartuPertemuan(
                p,
                namaMataKuliah: scope.namaMataKuliah(p.jadwal.mataKuliahId),
                mataKuliah: scope.mataKuliahDari(p.jadwal.mataKuliahId),
                hariIni: true,
              ),
            ),
      ],
    );
  }
}

class _BagianTenggat extends StatelessWidget {
  const _BagianTenggat({required this.tugas, required this.kumpul});

  final Stream<List<Tugas>> tugas;
  final Stream<Map<String, Pengumpulan>> kumpul;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return StreamBuilder<Map<String, Pengumpulan>>(
      stream: kumpul,
      builder: (context, kumpulSnap) => StreamBuilder<List<Tugas>>(
        stream: tugas,
        builder: (context, snap) {
          final sudah = kumpulSnap.data ?? const {};
          final dekat = (snap.data ?? const <Tugas>[])
              .where((t) => t.mendekatiTenggat(const Duration(days: 7)))
              .where((t) => scope.pengguna.isAdmin || !sudah.containsKey(t.id))
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              JudulBagian(
                'Tenggat Terdekat',
                jumlah: dekat.length,
                aksi: 'Semua',
                onAksi: () => scope.bukaTab(2),
              ),
              if (!snap.hasData)
                const KartuKerangka()
              else if (dekat.isEmpty)
                const Kartu(
                  child: KeadaanKosong(
                    ikon: Icons.task_alt,
                    judul: 'Tidak ada tenggat dalam 7 hari',
                    pesan: 'Semua tugas aman untuk saat ini.',
                    ringkas: true,
                  ),
                )
              else
                for (final t in dekat)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _KartuTenggatDashboard(tugas: t),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _KartuTenggatDashboard extends StatelessWidget {
  const _KartuTenggatDashboard({required this.tugas});

  final Tugas tugas;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final mendesak = tugas.mendekatiTenggat(const Duration(hours: 24));
    final jenis = mendesak ? JenisStatus.bahaya : JenisStatus.netral;
    return Kartu(
      onTap: () => bukaDetailTugas(context, tugas),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IkonKotak(
                mendesak
                    ? Icons.priority_high_rounded
                    : Icons.assignment_outlined,
                jenis: mendesak ? JenisStatus.bahaya : JenisStatus.info,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scope.namaMataKuliah(tugas.mataKuliahId),
                      style: t.bodySmall,
                    ),
                    Text(tugas.judul, style: t.titleMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: jenis.latar,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.alarm, size: 18, color: jenis.depan),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    formatTenggat(tugas.tenggat),
                    style: t.labelLarge?.copyWith(color: jenis.depan),
                  ),
                ),
                Text(
                  'Sisa ${formatDurasi(tugas.tenggat.difference(DateTime.now()))}',
                  style: t.labelMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sapaan sesuai waktu setempat.
String _sapaan(int jam) => switch (jam) {
  < 11 => 'Selamat pagi',
  < 15 => 'Selamat siang',
  < 18 => 'Selamat sore',
  _ => 'Selamat malam',
};
