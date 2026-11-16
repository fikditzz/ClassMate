import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/pengumpulan.dart';
import '../models/tugas.dart';
import '../widgets/animasi.dart';
import '../widgets/animasi_lanjut.dart';
import '../widgets/umum.dart';
import 'tugas_detail_page.dart';

enum _Filter { semua, belum, sudah }

/// Lembar buat tugas, atau ubah tugas bila [awal] diisi. Mengembalikan `true`
/// bila tersimpan.
Future<bool?> bukaFormTugas(BuildContext context, {Tugas? awal}) {
  final scope = AppScope.baca(context);
  return bukaLembar<bool>(
    context,
    judul: awal == null ? 'Buat Tugas Baru' : 'Ubah Tugas',
    subjudul: awal == null
        ? 'Anggota bisa mengumpulkan sampai tenggat.'
        : 'Pengumpulan yang sudah masuk tidak terhapus.',
    isi: (_) => _FormTugas(scope: scope, awal: awal),
  );
}

class TugasPage extends StatefulWidget {
  const TugasPage({super.key});

  @override
  State<TugasPage> createState() => _TugasPageState();
}

class _TugasPageState extends State<TugasPage> {
  late Stream<List<Tugas>> _tugas;
  late Stream<Map<String, Pengumpulan>> _milikSaya;
  final _cari = TextEditingController();
  var _filter = _Filter.semua;

  @override
  void initState() {
    super.initState();
    final scope = AppScope.baca(context);
    _tugas = scope.tugas.daftarTugas();
    _milikSaya = scope.tugas.pengumpulanSaya();
    _cari.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  /// Untuk Admin, "belum/sudah" berarti tugas aktif/ditutup.
  bool _cocok(Tugas t, Map<String, Pengumpulan> kumpul, bool admin) {
    final selesai = admin ? t.sudahLewatTenggat() : kumpul.containsKey(t.id);
    return switch (_filter) {
      _Filter.semua => true,
      _Filter.belum => !selesai,
      _Filter.sudah => selesai,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final admin = scope.pengguna.isAdmin;

    return Scaffold(
      appBar: appBarClassMate(
        context,
        judul: admin ? 'Kelola Tugas' : 'Tugas Kuliah',
      ),
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => bukaFormTugas(context),
              icon: const Icon(Icons.add),
              label: const Text('Buat Tugas'),
            )
          : null,
      body: StreamBuilder<Map<String, Pengumpulan>>(
        stream: _milikSaya,
        builder: (context, kumpulSnap) => StreamBuilder<List<Tugas>>(
          stream: _tugas,
          builder: (context, snap) {
            final kumpul = kumpulSnap.data ?? const <String, Pengumpulan>{};
            final semua = snap.data ?? const <Tugas>[];
            final kata = _cari.text.trim().toLowerCase();
            final cocokCari = semua.where(
              (t) =>
                  kata.isEmpty ||
                  t.judul.toLowerCase().contains(kata) ||
                  scope
                      .namaMataKuliah(t.mataKuliahId)
                      .toLowerCase()
                      .contains(kata),
            );
            final tampil = cocokCari
                .where((t) => _cocok(t, kumpul, admin))
                .toList();
            int hitung(_Filter f) {
              final lama = _filter;
              _filter = f;
              final n = cocokCari.where((t) => _cocok(t, kumpul, admin)).length;
              _filter = lama;
              return n;
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                TextField(
                  controller: _cari,
                  decoration: InputDecoration(
                    hintText: 'Cari tugas atau mata kuliah…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _cari.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _cari.clear,
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in _Filter.values) ...[
                        _ChipFilter(
                          label: switch (f) {
                            _Filter.semua => 'Semua',
                            _Filter.belum => admin ? 'Aktif' : 'Belum',
                            _Filter.sudah => admin ? 'Ditutup' : 'Sudah',
                          },
                          jumlah: snap.hasData ? hitung(f) : null,
                          aktif: _filter == f,
                          onTap: () => setState(() => _filter = f),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (snap.hasError)
                  KeadaanKosong(
                    ikon: Icons.error_outline,
                    judul: 'Gagal memuat tugas',
                    pesan: '${snap.error}',
                  )
                else if (!snap.hasData)
                  for (var i = 0; i < 3; i++) ...[
                    const KartuKerangka(),
                    const SizedBox(height: 12),
                  ]
                else if (tampil.isEmpty)
                  KeadaanKosong(
                    ikon: Icons.assignment_outlined,
                    judul: semua.isEmpty
                        ? 'Belum ada tugas'
                        : 'Tidak ada tugas yang cocok',
                    pesan: semua.isEmpty
                        ? (admin
                              ? 'Tekan "Buat Tugas" untuk menambahkan.'
                              : 'Tugas dari admin kelas akan muncul di sini.')
                        : 'Coba ubah kata kunci atau filter.',
                  )
                else
                  for (final (i, t) in tampil.indexed) ...[
                    // Kunci memuat filter, jadi daftar beranimasi ulang
                    // setiap filter diganti.
                    Muncul(
                      key: ValueKey('${_filter.name}-${t.id}'),
                      urutan: i,
                      child: _KartuTugas(tugas: t, pengumpulan: kumpul[t.id]),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ChipFilter extends StatelessWidget {
  const _ChipFilter({
    required this.label,
    required this.aktif,
    required this.onTap,
    this.jumlah,
  });

  final String label;
  final int? jumlah;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Warna latar, garis, dan teks berganti dengan transisi singkat.
    return AnimatedContainer(
      duration: Gerak.sedang,
      curve: Gerak.kurva,
      decoration: ShapeDecoration(
        color: aktif ? Warna.primerMuda : Warna.permukaan,
        shape: StadiumBorder(
          side: BorderSide(color: aktif ? Warna.primerMuda : Warna.garis),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: AnimatedDefaultTextStyle(
              duration: Gerak.sedang,
              style: Theme.of(context).textTheme.labelLarge!
                  .copyWith(color: aktif ? Warna.primer : Warna.teks),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  if (jumlah != null) ...[
                    const Text(' ('),
                    AngkaBerganti(jumlah!),
                    const Text(')'),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KartuTugas extends StatelessWidget {
  const _KartuTugas({required this.tugas, this.pengumpulan});

  final Tugas tugas;
  final Pengumpulan? pengumpulan;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final admin = scope.pengguna.isAdmin;
    final lewat = tugas.sudahLewatTenggat();
    final mendesak = tugas.mendekatiTenggat(const Duration(hours: 24));
    final p = pengumpulan;

    // Chip hanya untuk status yang perlu diperhatikan. Status biasa
    // ("belum dikumpulkan") sudah tersirat dari filter dan tidak diulang.
    final ({String teks, JenisStatus jenis, IconData? ikon})? status;
    if (!admin && p != null) {
      status = (
        teks: 'Terkumpul',
        jenis: JenisStatus.sukses,
        ikon: Icons.check_circle_outline,
      );
    } else if (lewat) {
      status = admin
          ? (teks: 'Ditutup', jenis: JenisStatus.netral, ikon: null)
          : (
              teks: 'Terlambat',
              jenis: JenisStatus.bahaya,
              ikon: Icons.error_outline,
            );
    } else if (mendesak) {
      status = (
        teks: '< 24 jam',
        jenis: JenisStatus.peringatan,
        ikon: Icons.schedule,
      );
    } else {
      status = null;
    }
    final strip = status == null || status.jenis == JenisStatus.netral
        ? null
        : status.jenis.strip;
    final warnaTenggat = lewat && !admin
        ? Warna.bahaya
        : mendesak
        ? Warna.peringatanTeks
        : Warna.teksSekunder;

    return Kartu(
      strip: strip,
      onTap: () =>
          bukaDetailTugas(context, tugas, tagJudul: _tagJudul(tugas.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  scope.namaMataKuliah(tugas.mataKuliahId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelMedium?.copyWith(color: Warna.teksSekunder),
                ),
              ),
              if (status != null) ...[
                const SizedBox(width: 8),
                ChipStatus(status.teks, jenis: status.jenis, ikon: status.ikon),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // Judul "terbang" ke halaman detail saat kartu diketuk.
          JudulHero(
            tag: _tagJudul(tugas.id),
            teks: tugas.judul,
            style: t.titleLarge,
          ),
          const SizedBox(height: 10),
          if (!admin && p != null)
            KotakInfo(
              jenis: JenisStatus.sukses,
              ikon: Icons.cloud_done_outlined,
              judul: 'Diunggah ${formatTenggat(p.waktuUpload)}',
              teks: '${p.namaFile} • ${formatUkuran(p.ukuran)}',
            )
          else
            // Tenggat dan sisa waktu dalam satu baris.
            Row(
              children: [
                Icon(
                  lewat ? Icons.event_busy : Icons.timer_outlined,
                  size: 18,
                  color: warnaTenggat,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: formatTenggat(tugas.tenggat),
                      style: t.labelLarge?.copyWith(color: warnaTenggat),
                      children: [
                        if (!lewat)
                          TextSpan(
                            text:
                                '  •  sisa ${formatDurasi(tugas.tenggat.difference(DateTime.now()))}',
                            style: t.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _FormTugas extends StatefulWidget {
  const _FormTugas({required this.scope, this.awal});

  final AppScope scope;
  final Tugas? awal;

  @override
  State<_FormTugas> createState() => _FormTugasState();
}

class _FormTugasState extends State<_FormTugas> {
  final _kunci = GlobalKey<FormState>();
  late final _judul = TextEditingController(text: widget.awal?.judul ?? '');
  late final _deskripsi = TextEditingController(
    text: widget.awal?.deskripsi ?? '',
  );
  late String? _mk = widget.awal?.mataKuliahId;
  late DateTime? _tenggat = widget.awal?.tenggat;
  bool _memproses = false;

  @override
  void dispose() {
    _judul.dispose();
    _deskripsi.dispose();
    super.dispose();
  }

  Future<void> _pilihTenggat() async {
    final sekarang = DateTime.now();
    final awal = _tenggat;
    final tanggal = await showDatePicker(
      context: context,
      // Tugas lama yang diedit boleh tetap memakai tenggatnya.
      firstDate: awal != null && awal.isBefore(sekarang) ? awal : sekarang,
      lastDate: sekarang.add(const Duration(days: 365)),
      initialDate: _tenggat ?? sekarang.add(const Duration(days: 7)),
    );
    if (tanggal == null || !mounted) return;
    final jam = await showTimePicker(
      context: context,
      initialTime: awal == null
          ? const TimeOfDay(hour: 23, minute: 59)
          : TimeOfDay.fromDateTime(awal),
    );
    if (jam == null) return;
    setState(
      () => _tenggat = DateTime(
        tanggal.year,
        tanggal.month,
        tanggal.day,
        jam.hour,
        jam.minute,
      ),
    );
  }

  Future<void> _simpan() async {
    if (!_kunci.currentState!.validate()) return;
    final awal = widget.awal;
    final tenggatBerubah = awal == null || _tenggat != awal.tenggat;
    if (_tenggat == null ||
        (tenggatBerubah && !_tenggat!.isAfter(DateTime.now()))) {
      tampilkanPesan(context, 'Pilih tenggat di masa depan.', gagal: true);
      return;
    }
    setState(() => _memproses = true);
    final tugas = Tugas(
      id: awal?.id ?? '',
      mataKuliahId: _mk!,
      judul: _judul.text.trim(),
      deskripsi: _deskripsi.text.trim(),
      tenggat: _tenggat!,
      dibuatOleh: awal?.dibuatOleh ?? '',
    );
    try {
      if (awal == null) {
        await widget.scope.tugas.buatTugas(tugas);
      } else {
        await widget.scope.tugas.ubahTugas(tugas);
      }
      if (mounted) {
        Navigator.pop(context, true);
        tampilkanPesan(
          context,
          awal == null ? 'Tugas berhasil dibuat.' : 'Tugas diperbarui.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _memproses = false);
        tampilkanPesan(context, 'Gagal menyimpan tugas: $e', gagal: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mk = widget.scope.mataKuliah;
    if (mk.isEmpty) return const _BelumAdaMataKuliah();
    return Form(
      key: _kunci,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _judul,
            decoration: const InputDecoration(labelText: 'Judul tugas'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Judul wajib diisi' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _mk,
            decoration: const InputDecoration(labelText: 'Mata kuliah'),
            items: [
              for (final m in mk)
                DropdownMenuItem(value: m.id, child: Text(m.nama)),
            ],
            onChanged: (v) => setState(() => _mk = v),
            validator: (v) => v == null ? 'Pilih mata kuliah' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _deskripsi,
            decoration: const InputDecoration(
              labelText: 'Instruksi pengerjaan',
              alignLabelWithHint: true,
            ),
            minLines: 3,
            maxLines: 6,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pilihTenggat,
            icon: const Icon(Icons.event_outlined),
            label: Text(
              _tenggat == null
                  ? 'Pilih tenggat pengumpulan'
                  : 'Tenggat: ${formatTenggat(_tenggat!)}',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _memproses ? null : _simpan,
            child: Text(
              _memproses
                  ? 'Menyimpan…'
                  : widget.awal == null
                  ? 'Terbitkan Tugas'
                  : 'Simpan Perubahan',
            ),
          ),
        ],
      ),
    );
  }
}

class _BelumAdaMataKuliah extends StatelessWidget {
  const _BelumAdaMataKuliah();

  @override
  Widget build(BuildContext context) => const KeadaanKosong(
    ikon: Icons.menu_book_outlined,
    judul: 'Belum ada mata kuliah',
    pesan: 'Admin bisa menambahkannya di Profil → Kelola mata kuliah.',
    ringkas: true,
  );
}

/// Tag Hero judul tugas. Hanya daftar di tab Tugas yang memakainya, agar
/// tidak bentrok dengan judul yang sama di tab lain (semua tab hidup
/// bersamaan di IndexedStack).
String _tagJudul(String tugasId) => 'judul-tugas-$tugasId';
