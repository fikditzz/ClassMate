import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/errors.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../ekspor/bagikan.dart';
import '../ekspor/dokumen_rekap.dart';
import '../ekspor/isi_rekap.dart';
import '../models/kas.dart';
import '../models/rekap.dart';
import '../widgets/animasi.dart';
import '../widgets/animasi_lanjut.dart';
import '../widgets/umum.dart';
import 'rekap_kehadiran_page.dart' show jenisKehadiran;

/// Membuka halaman Rekap & Ekspor (admin kelas dan dosen).
Future<void> bukaRekap(BuildContext context) {
  final scope = AppScope.baca(context);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => scope.bungkus(const RekapPage())),
  );
}

enum _Jenis {
  hadir('Absen', Icons.how_to_reg_outlined),
  tugas('Tugas', Icons.assignment_outlined),
  kas('Kas', Icons.account_balance_wallet_outlined);

  const _Jenis(this.label, this.ikon);

  final String label;
  final IconData ikon;
}

/// Hasil muat: dokumen siap ekspor dan data untuk pratinjau.
class _Hasil {
  const _Hasil(this.dokumen, {this.absen, this.tugas, this.kas});

  final DokumenRekap dokumen;
  final RekapAbsenMk? absen;
  final RekapTugasMk? tugas;
  final _DataKas? kas;
}

class _DataKas {
  const _DataKas(this.ringkasan, this.status, this.jumlahTransaksi);

  final RingkasanKas ringkasan;
  final List<StatusIuran> status;
  final int jumlahTransaksi;
}

class RekapPage extends StatefulWidget {
  const RekapPage({super.key});

  @override
  State<RekapPage> createState() => _RekapPageState();
}

class _RekapPageState extends State<RekapPage> {
  var _jenis = _Jenis.hadir;
  String? _mkId;
  Future<_Hasil>? _hasil;
  late final Future<String?> _namaKelas;
  FormatEkspor? _mengekspor;

  @override
  void initState() {
    super.initState();
    final scope = AppScope.baca(context);
    _namaKelas = scope.rekap.namaKelas().catchError((_) => null);
    _mkId = scope.mataKuliah.firstOrNull?.id;
    _hasil = _muat();
  }

  Future<_Hasil> _muat() async {
    final scope = AppScope.baca(context);
    final namaKelas = await _namaKelas;
    if (_jenis == _Jenis.kas) {
      final (riwayat, status, ringkasan) = await (
        scope.kas.riwayatKelas(),
        scope.kas.statusIuran(),
        scope.kas.ringkasan(),
      ).wait;
      return _Hasil(
        dokumenKas(
          riwayat: riwayat,
          status: status,
          ringkasan: ringkasan,
          namaKelas: namaKelas ?? 'Kelas',
        ),
        kas: _DataKas(ringkasan, status, riwayat.length),
      );
    }
    final mk = _mkId == null ? null : scope.mataKuliahDari(_mkId!);
    if (mk == null) {
      throw const ClassMateException('Belum ada mata kuliah untuk direkap.');
    }
    final jadwal = await scope.jadwal.semuaJadwal().first;
    final info = InfoMk(
      mataKuliah: mk,
      kelas: KopDokumen.hurufKelas(namaKelas),
      jadwal: jadwal.where((j) => j.mataKuliahId == mk.id).toList(),
    );
    if (_jenis == _Jenis.tugas) {
      final r = await scope.rekap.rekapTugas(mk.id);
      return _Hasil(dokumenRekapTugas(r, info), tugas: r);
    }
    final r = await scope.rekap.rekapAbsen(mk.id);
    return _Hasil(dokumenDaftarHadir(r, info), absen: r);
  }

  void _ganti({_Jenis? jenis, String? mkId}) {
    setState(() {
      _jenis = jenis ?? _jenis;
      _mkId = mkId ?? _mkId;
      _hasil = _muat();
    });
  }

  Future<void> _segarkan() async {
    final baru = _muat();
    setState(() => _hasil = baru);
    try {
      await baru;
    } catch (_) {
      // Galat ditampilkan oleh FutureBuilder.
    }
  }

  Future<void> _ekspor(FormatEkspor format) async {
    final hasil = _hasil;
    if (hasil == null || _mengekspor != null) return;
    setState(() => _mengekspor = format);
    try {
      await eksporDokumen((await hasil).dokumen, format);
    } catch (e) {
      if (mounted) {
        tampilkanPesan(
          context,
          e is ClassMateException ? e.pesan : 'Gagal membuat berkas: $e',
          gagal: true,
        );
      }
    } finally {
      if (mounted) setState(() => _mengekspor = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final jenisTersedia = [
      _Jenis.hadir,
      _Jenis.tugas,
      if (scope.pengguna.bolehKelolaAkun) _Jenis.kas,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Rekap & Ekspor')),
      body: RefreshIndicator(
        onRefresh: _segarkan,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            SegmentedButton<_Jenis>(
              showSelectedIcon: false,
              segments: [
                for (final j in jenisTersedia)
                  ButtonSegment(
                    value: j,
                    icon: Icon(j.ikon, size: 18),
                    label: Text(j.label),
                  ),
              ],
              selected: {_jenis},
              onSelectionChanged: (s) => _ganti(jenis: s.first),
            ),
            if (_jenis != _Jenis.kas) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _mkId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Mata kuliah',
                  prefixIcon: Icon(Icons.menu_book_outlined),
                ),
                items: [
                  for (final mk in scope.mataKuliah)
                    DropdownMenuItem(
                      value: mk.id,
                      child: Text(mk.nama, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (id) => id == null ? null : _ganti(mkId: id),
              ),
            ],
            const SizedBox(height: 16),
            FutureBuilder<_Hasil>(
              future: _hasil,
              builder: (context, snap) {
                if (snap.hasError) {
                  final e = snap.error;
                  return KeadaanKosong(
                    ikon: Icons.cloud_off_outlined,
                    judul: 'Rekap belum bisa dimuat',
                    pesan: e is ClassMateException ? e.pesan : '$e',
                  );
                }
                final h = snap.data;
                if (snap.connectionState != ConnectionState.done || h == null) {
                  return const KartuKerangka();
                }
                return switch (h) {
                  _Hasil(:final absen?) => _PratinjauHadir(absen),
                  _Hasil(:final tugas?) => _PratinjauTugas(tugas),
                  _Hasil(:final kas?) => _PratinjauKas(kas),
                  _ => const SizedBox(),
                };
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: _TombolEkspor(
        sedang: _mengekspor,
        onEkspor: _ekspor,
      ),
    );
  }
}

class _TombolEkspor extends StatelessWidget {
  const _TombolEkspor({required this.sedang, required this.onEkspor});

  final FormatEkspor? sedang;
  final ValueChanged<FormatEkspor> onEkspor;

  @override
  Widget build(BuildContext context) {
    Widget ikon(FormatEkspor f, IconData i) => sedang == f
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(i, size: 20);
    final sibuk = sedang != null;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Warna.permukaan,
        border: Border(top: BorderSide(color: Warna.garis)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: sibuk ? null : () => onEkspor(FormatEkspor.pdf),
                  icon: ikon(FormatEkspor.pdf, Icons.picture_as_pdf_outlined),
                  label: const Text('Unduh PDF'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: sibuk ? null : () => onEkspor(FormatEkspor.excel),
                  icon: ikon(FormatEkspor.excel, Icons.grid_on_outlined),
                  label: const Text('Unduh Excel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu ringkasan di atas pratinjau.
class _KartuRingkas extends StatelessWidget {
  const _KartuRingkas({
    required this.nilai,
    required this.jenis,
    required this.judul,
    required this.baris,
  });

  final double nilai;
  final JenisStatus jenis;
  final String judul;
  final List<String> baris;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Muncul(
      child: Kartu(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CincinPersen(
              nilai: nilai,
              warna: jenis.depan,
              latar: jenis.latar,
              ukuran: 88,
              tebal: 9,
              style: t.titleLarge?.copyWith(color: jenis.depan),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LabelAtas(judul),
                  const SizedBox(height: 4),
                  for (final (i, b) in baris.indexed)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        b,
                        style: i == 0 ? t.titleMedium : t.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kotak kecil satu sel daftar hadir: H hijau, A merah, ujian abu-abu,
/// belum berlangsung bergaris.
class _KotakSel extends StatelessWidget {
  const _KotakSel(this.isi, {this.label});

  final IsiSel isi;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final (latar, depan) = switch (isi) {
      IsiSel.hadir => (Warna.suksesMuda, Warna.sukses),
      IsiSel.tidakHadir => (Warna.bahayaMuda, Warna.bahaya),
      IsiSel.ujian => (Warna.netralMuda, Warna.netral),
      IsiSel.kosong => (Colors.transparent, Warna.garis),
    };
    return Container(
      width: 15,
      height: 15,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(4),
        border: isi == IsiSel.kosong ? Border.all(color: Warna.garis) : null,
      ),
      child: Text(
        label ?? isi.teks,
        style: TextStyle(
          fontSize: 8.5,
          height: 1,
          fontWeight: FontWeight.w700,
          color: depan,
        ),
      ),
    );
  }
}

class _BarisMahasiswa extends StatelessWidget {
  const _BarisMahasiswa({
    required this.mahasiswa,
    required this.no,
    required this.kanan,
    required this.sel,
  });

  final MahasiswaRekap mahasiswa;
  final int no;
  final Widget kanan;
  final List<Widget> sel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '$no',
                  style: t.bodySmall?.copyWith(fontFeatures: angkaTabular),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mahasiswa.nama,
                      style: t.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      mahasiswa.stambuk,
                      style: t.bodySmall?.copyWith(fontFeatures: angkaTabular),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              kanan,
            ],
          ),
          if (sel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Wrap(spacing: 3, runSpacing: 3, children: sel),
            ),
          ],
        ],
      ),
    );
  }
}

class _PratinjauHadir extends StatelessWidget {
  const _PratinjauHadir(this.r);

  final RekapAbsenMk r;

  @override
  Widget build(BuildContext context) {
    final rata = r.rataRata;
    final kurang = r.mahasiswa
        .where((m) => (r.persen(m.id) ?? 1) < batasHadir)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KartuRingkas(
          nilai: rata ?? 0,
          jenis: rata == null ? JenisStatus.netral : jenisKehadiran(rata),
          judul: 'Rata-rata kehadiran',
          baris: [
            '${r.pertemuan.length} pertemuan',
            '${r.mahasiswa.length} mahasiswa',
            if (kurang > 0) '$kurang mahasiswa di bawah 75%',
          ],
        ),
        const SizedBox(height: 12),
        const KotakInfo(
          ikon: Icons.description_outlined,
          teks:
              'Format daftar hadir kampus: 15 mahasiswa per halaman, kolom '
              '1–7, UTS, 8–14, UAS, ditambah lembar rekapitulasi.',
        ),
        JudulBagian('Mahasiswa', jumlah: r.mahasiswa.length, atas: 20),
        if (r.mahasiswa.isEmpty)
          const KeadaanKosong(
            ikon: Icons.groups_outlined,
            judul: 'Belum ada mahasiswa',
            pesan: 'Tambahkan akun anggota kelas di menu Kelola Akun.',
          )
        else
          Kartu(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (final (i, m) in r.mahasiswa.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  _BarisMahasiswa(
                    no: i + 1,
                    mahasiswa: m,
                    kanan: switch (r.persen(m.id)) {
                      null => const ChipStatus('-', jenis: JenisStatus.netral),
                      final p => ChipStatus(
                        '${r.jumlahHadir(m.id)}/${r.pertemuan.length} • '
                        '${(p * 100).round()}%',
                        jenis: jenisKehadiran(p),
                      ),
                    },
                    sel: [
                      for (var k = 0; k < RekapAbsenMk.labelKolom.length; k++)
                        _KotakSel(
                          r.sel(k, m.id),
                          label: RekapAbsenMk.kolomUjian(k) ? '-' : null,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _PratinjauTugas extends StatelessWidget {
  const _PratinjauTugas(this.r);

  final RekapTugasMk r;

  @override
  Widget build(BuildContext context) {
    final total = r.tugas.length * r.mahasiswa.length;
    final kumpul = r.mahasiswa.fold(0, (s, m) => s + r.jumlahTerkumpul(m.id));
    final rata = total == 0 ? null : kumpul / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KartuRingkas(
          nilai: rata ?? 0,
          jenis: rata == null ? JenisStatus.netral : jenisKehadiran(rata),
          judul: 'Tingkat pengumpulan',
          baris: ['${r.tugas.length} tugas', '$kumpul dari $total pengumpulan'],
        ),
        if (r.tugas.isNotEmpty) ...[
          JudulBagian('Tugas', jumlah: r.tugas.length, atas: 20),
          Kartu(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                for (final (i, t) in r.tugas.indexed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: IkonKotak(Icons.assignment_outlined, ukuran: 36),
                    title: Text('T${i + 1} · ${t.judul}'),
                    subtitle: Text(
                      'Tenggat ${formatTanggalSingkat(t.tenggat)}',
                    ),
                    trailing: Text(
                      '${r.pengumpulTugas(t.id)}/${r.mahasiswa.length}',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontFeatures: angkaTabular),
                    ),
                  ),
              ],
            ),
          ),
        ],
        JudulBagian('Mahasiswa', jumlah: r.mahasiswa.length, atas: 20),
        if (r.tugas.isEmpty)
          const KeadaanKosong(
            ikon: Icons.assignment_outlined,
            judul: 'Belum ada tugas',
            pesan: 'Rekap terisi setelah tugas mata kuliah ini dibuat.',
          )
        else
          Kartu(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (final (i, m) in r.mahasiswa.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  _BarisMahasiswa(
                    no: i + 1,
                    mahasiswa: m,
                    kanan: ChipStatus(
                      '${r.jumlahTerkumpul(m.id)}/${r.tugas.length}',
                      jenis: r.jumlahTerkumpul(m.id) == r.tugas.length
                          ? JenisStatus.sukses
                          : JenisStatus.peringatan,
                    ),
                    sel: [
                      for (final (k, t) in r.tugas.indexed)
                        _KotakSel(
                          r.terkumpul(t.id, m.id)
                              ? IsiSel.hadir
                              : IsiSel.tidakHadir,
                          label: '${k + 1}',
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _PratinjauKas extends StatelessWidget {
  const _PratinjauKas(this.d);

  final _DataKas d;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final aturan = d.ringkasan.aturan;
    final lunas = d.status.where((s) => s.tunggakan(aturan) == 0).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KartuRingkas(
          nilai: d.status.isEmpty ? 0 : lunas / d.status.length,
          jenis: JenisStatus.info,
          judul: 'Saldo kas',
          baris: [
            formatRupiah(d.ringkasan.saldo),
            '${d.jumlahTransaksi} transaksi tercatat',
            '$lunas dari ${d.status.length} anggota lunas iuran',
          ],
        ),
        const SizedBox(height: 12),
        const KotakInfo(
          ikon: Icons.description_outlined,
          teks:
              'Laporan berisi buku kas lengkap dengan saldo berjalan dan '
              'status iuran tiap anggota.',
        ),
        JudulBagian('Status iuran', jumlah: d.status.length, atas: 20),
        Kartu(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              for (final (i, s) in d.status.indexed) ...[
                if (i > 0) const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      AvatarInisial(s.nama, ukuran: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.nama,
                              style: t.titleSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${s.kaliBayar}× bayar • '
                              '${formatRupiah(s.totalBayar)}',
                              style: t.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      switch (s.tunggakan(aturan)) {
                        0 => const ChipStatus(
                          'Lunas',
                          jenis: JenisStatus.sukses,
                        ),
                        final n => ChipStatus(
                          formatRupiah(n),
                          jenis: JenisStatus.bahaya,
                        ),
                      },
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
