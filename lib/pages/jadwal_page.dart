import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/jadwal.dart';
import '../models/perubahan_jadwal.dart';
import '../models/tugas.dart';
import '../widgets/animasi.dart';
import '../widgets/kartu_jadwal.dart';
import '../widgets/umum.dart';
import 'tugas_detail_page.dart';

enum _Mode { harian, mingguan }

DateTime _senin(DateTime t) =>
    tanggalSaja(t).subtract(Duration(days: t.weekday - 1));

class JadwalPage extends StatefulWidget {
  const JadwalPage({super.key});

  @override
  State<JadwalPage> createState() => _JadwalPageState();
}

class _JadwalPageState extends State<JadwalPage> {
  late Stream<List<Jadwal>> _jadwal;
  late Stream<List<PerubahanJadwal>> _perubahan;
  late Stream<List<Tugas>> _tugas;
  var _mode = _Mode.harian;
  DateTime _tanggal = tanggalSaja(DateTime.now());
  DateTime _awalMinggu = _senin(DateTime.now());

  /// Data terakhir dari stream, dipakai tombol tambah di luar StreamBuilder.
  List<Jadwal> _semuaJadwal = const [];
  List<PerubahanJadwal> _semuaPerubahan = const [];

  /// Strip tanggal digeser agar tanggal terpilih ada di tengah.
  final _strip = ScrollController();
  DateTime? _sudahDigeserKe;

  static const _lebarChip = 64.0, _jarakChip = 8.0;

  @override
  void initState() {
    super.initState();
    final scope = AppScope.baca(context);
    _jadwal = scope.jadwal.semuaJadwal();
    _perubahan = scope.jadwal.perubahanJadwal();
    _tugas = scope.tugas.daftarTugas();
  }

  @override
  void dispose() {
    _strip.dispose();
    super.dispose();
  }

  /// Dipanggil setelah frame: geser strip sekali setiap tanggal berganti,
  /// supaya tidak melawan geseran manual pengguna.
  void _geserStripKeTanggal() {
    if (_sudahDigeserKe == _tanggal) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_strip.hasClients) return;
      _sudahDigeserKe = _tanggal;
      final i = _tanggal.weekday - 1;
      final pos = _strip.position;
      final tujuan =
          i * (_lebarChip + _jarakChip) -
          (pos.viewportDimension - _lebarChip) / 2;
      _strip.animateTo(
        tujuan.clamp(0.0, pos.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _bukaForm(Jadwal? awal) {
    final scope = AppScope.baca(context);
    bukaLembar<void>(
      context,
      judul: awal == null ? 'Tambah Jadwal Tetap' : 'Ubah Jadwal Tetap',
      subjudul:
          'Berlaku setiap minggu. Bentrok dengan jadwal lain diperiksa '
          'sebelum disimpan.',
      isi: (_) =>
          _FormJadwal(scope: scope, awal: awal, hariAwal: _tanggal.weekday),
    );
  }

  /// Lembar perubahan satu pertemuan (libur, pindah, atau tambahan).
  void _bukaFormPerubahan({
    required JenisPerubahan jenis,
    Pertemuan? sumber,
    PerubahanJadwal? awal,
    String? mataKuliahId,
  }) {
    final scope = AppScope.baca(context);
    bukaLembar<void>(
      context,
      judul: switch (jenis) {
        JenisPerubahan.libur => 'Liburkan Pertemuan',
        JenisPerubahan.pindah => 'Pindahkan Pertemuan',
        JenisPerubahan.tambahan =>
          awal == null ? 'Tambah Kuliah Sekali' : 'Ubah Kuliah Tambahan',
      },
      subjudul: switch (jenis) {
        JenisPerubahan.libur =>
          'Hanya pertemuan ini yang libur. Minggu lain tetap masuk.',
        JenisPerubahan.pindah =>
          'Hanya pertemuan ini yang pindah. Jadwal tetap tidak berubah.',
        JenisPerubahan.tambahan =>
          'Kuliah pengganti atau tambahan yang hanya terjadi sekali.',
      },
      isi: (_) => _FormPerubahan(
        scope: scope,
        jenis: jenis,
        sumber: sumber,
        awal: awal,
        mataKuliahId: mataKuliahId,
        tanggalAwal: _tanggal,
        jadwal: _semuaJadwal,
        perubahan: _semuaPerubahan,
      ),
    );
  }

  Future<void> _batalkanPerubahan(PerubahanJadwal p, String pesan) async {
    try {
      await AppScope.baca(context).jadwal.hapusPerubahan(p.id);
      if (mounted) tampilkanPesan(context, pesan);
    } catch (e) {
      if (mounted) tampilkanPesan(context, '$e', gagal: true);
    }
  }

  /// Pilihan admin saat mengetuk satu pertemuan.
  Future<void> _aturPertemuan(Pertemuan p) async {
    final scope = AppScope.baca(context);
    final asal = p.asal;
    final ubah = p.perubahan;
    final pilihan = <_Pilihan>[
      if (p.status == StatusPertemuan.biasa) ...[
        _Pilihan(
          Icons.check_circle_outline,
          'Tetap masuk sesuai jadwal',
          'Tidak ada perubahan untuk pertemuan ini.',
          () {},
        ),
        _Pilihan(
          Icons.update,
          'Pindahkan pertemuan ini',
          'Ke hari atau jam lain, hanya untuk tanggal ini.',
          () => _bukaFormPerubahan(jenis: JenisPerubahan.pindah, sumber: p),
        ),
        _Pilihan(
          Icons.event_busy_outlined,
          'Liburkan pertemuan ini',
          'Kuliah tanggal ini ditiadakan.',
          () => _bukaFormPerubahan(jenis: JenisPerubahan.libur, sumber: p),
        ),
      ],
      if (p.status == StatusPertemuan.libur) ...[
        _Pilihan(
          Icons.event_available_outlined,
          'Batalkan libur',
          'Pertemuan kembali masuk sesuai jadwal.',
          () => _batalkanPerubahan(ubah!, 'Libur dibatalkan.'),
        ),
        _Pilihan(
          Icons.update,
          'Pindahkan ke hari lain',
          'Ganti libur menjadi pemindahan jadwal.',
          () => _bukaFormPerubahan(
            jenis: JenisPerubahan.pindah,
            sumber: p,
            awal: ubah,
          ),
        ),
      ],
      if (p.status == StatusPertemuan.dipindahKeluar ||
          p.status == StatusPertemuan.pengganti) ...[
        _Pilihan(
          Icons.edit_calendar_outlined,
          'Ubah tanggal atau jam pindahan',
          'Pindahkan ke waktu lain.',
          () => _bukaFormPerubahan(
            jenis: JenisPerubahan.pindah,
            sumber: p,
            awal: ubah,
          ),
        ),
        _Pilihan(
          Icons.undo,
          'Kembalikan ke jadwal asal',
          'Pertemuan masuk di hari dan jam semula.',
          () => _batalkanPerubahan(ubah!, 'Pertemuan kembali ke jadwal asal.'),
        ),
        _Pilihan(
          Icons.event_busy_outlined,
          'Liburkan saja',
          'Pertemuan ditiadakan, tidak dipindah.',
          () => _bukaFormPerubahan(
            jenis: JenisPerubahan.libur,
            sumber: p,
            awal: ubah,
          ),
        ),
      ],
      if (p.status == StatusPertemuan.tambahan) ...[
        _Pilihan(
          Icons.edit_calendar_outlined,
          'Ubah kuliah tambahan',
          'Tanggal, jam, ruang, atau mata kuliah.',
          () => _bukaFormPerubahan(jenis: JenisPerubahan.tambahan, awal: ubah),
        ),
        _Pilihan(
          Icons.delete_outline,
          'Hapus kuliah tambahan',
          'Kuliah tambahan ini dibatalkan.',
          () => _batalkanPerubahan(ubah!, 'Kuliah tambahan dihapus.'),
          bahaya: true,
        ),
      ],
      _Pilihan(
        Icons.add_circle_outline,
        'Tambah pertemuan lain',
        'Kuliah pengganti atau tambahan di hari lain.',
        () => _bukaFormPerubahan(
          jenis: JenisPerubahan.tambahan,
          mataKuliahId: p.jadwal.mataKuliahId,
        ),
      ),
      if (asal != null)
        _Pilihan(
          Icons.repeat,
          'Ubah jadwal tetap mingguan',
          '${asal.namaHari}, ${asal.jamMulai}–${asal.jamSelesai}, berlaku '
              'setiap minggu.',
          () => _bukaForm(asal),
        ),
    ];

    final dipilih = await bukaLembar<VoidCallback>(
      context,
      judul: scope.namaMataKuliah(p.jadwal.mataKuliahId),
      subjudul:
          '${formatTanggalPanjang(p.tanggal)} • '
          '${p.jadwal.jamMulai}–${p.jadwal.jamSelesai}',
      isi: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final x in pilihan)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: IkonKotak(
                x.ikon,
                jenis: x.bahaya ? JenisStatus.bahaya : JenisStatus.info,
              ),
              title: Text(
                x.judul,
                style: x.bahaya ? const TextStyle(color: Warna.bahaya) : null,
              ),
              subtitle: Text(x.keterangan),
              onTap: () => Navigator.pop(ctx, x.aksi),
            ),
        ],
      ),
    );
    dipilih?.call();
  }

  /// Tombol tambah: jadwal tetap mingguan atau kuliah sekali.
  Future<void> _tambah() async {
    final dipilih = await bukaLembar<VoidCallback>(
      context,
      judul: 'Tambah Jadwal',
      isi: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final x in [
            _Pilihan(
              Icons.repeat,
              'Jadwal tetap mingguan',
              'Kuliah rutin yang berulang setiap minggu.',
              () => _bukaForm(null),
            ),
            _Pilihan(
              Icons.event_outlined,
              'Kuliah sekali (pengganti/tambahan)',
              'Hanya pada satu tanggal, misalnya ${formatHariTanggal(_tanggal)}.',
              () => _bukaFormPerubahan(jenis: JenisPerubahan.tambahan),
            ),
          ])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: IkonKotak(x.ikon),
              title: Text(x.judul),
              subtitle: Text(x.keterangan),
              onTap: () => Navigator.pop(ctx, x.aksi),
            ),
        ],
      ),
    );
    dipilih?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final admin = scope.pengguna.isAdmin;
    final onAtur = admin ? _aturPertemuan : null;

    return Scaffold(
      appBar: appBarClassMate(context, judul: 'Jadwal'),
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: _tambah,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Jadwal'),
            )
          : null,
      body: StreamBuilder<List<Tugas>>(
        stream: _tugas,
        builder: (context, tugasSnap) => StreamBuilder<List<PerubahanJadwal>>(
          stream: _perubahan,
          builder: (context, ubahSnap) => StreamBuilder<List<Jadwal>>(
            stream: _jadwal,
            builder: (context, snap) {
              final semua = _semuaJadwal = snap.data ?? const <Jadwal>[];
              final ubah = _semuaPerubahan =
                  ubahSnap.data ?? const <PerubahanJadwal>[];
              final tugas = (tugasSnap.data ?? const <Tugas>[]);
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<_Mode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: _Mode.harian,
                          icon: Icon(Icons.view_day_outlined),
                          label: Text('Harian'),
                        ),
                        ButtonSegment(
                          value: _Mode.mingguan,
                          icon: Icon(Icons.view_week_outlined),
                          label: Text('Mingguan'),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) => setState(() {
                        _mode = s.first;
                        _sudahDigeserKe = null; // strip dibangun ulang
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!snap.hasData)
                    const KartuKerangka()
                  else if (_mode == _Mode.harian)
                    ..._harian(context, semua, ubah, tugas, onAtur)
                  else
                    ..._mingguan(context, semua, ubah, tugas, onAtur),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _harian(
    BuildContext context,
    List<Jadwal> semua,
    List<PerubahanJadwal> ubah,
    List<Tugas> tugas,
    void Function(Pertemuan)? onAtur,
  ) {
    _geserStripKeTanggal();
    final scope = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final hariIni = DateUtils.isSameDay(_tanggal, DateTime.now());
    final daftar = pertemuanPada(_tanggal, semua, ubah);
    final tenggat = tugas
        .where((x) => DateUtils.isSameDay(x.tenggat, _tanggal))
        .toList();
    final awal = _senin(_tanggal);

    return [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LabelAtas('Jadwal kuliah'),
                const SizedBox(height: 2),
                Text(formatTanggalPanjang(_tanggal), style: t.headlineSmall),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Pilih tanggal',
            onPressed: () async {
              final dipilih = await showDatePicker(
                context: context,
                initialDate: _tanggal,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (dipilih != null) setState(() => _tanggal = dipilih);
            },
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 92,
        child: ListView.separated(
          controller: _strip,
          scrollDirection: Axis.horizontal,
          itemCount: 7,
          separatorBuilder: (_, _) => const SizedBox(width: _jarakChip),
          itemBuilder: (context, i) {
            final tgl = awal.add(Duration(days: i));
            final n = pertemuanPada(
              tgl,
              semua,
              ubah,
            ).where((p) => p.berlangsung).length;
            return _ChipTanggal(
              tanggal: tgl,
              jumlah: n,
              dipilih: DateUtils.isSameDay(tgl, _tanggal),
              onTap: () => setState(() => _tanggal = tgl),
            );
          },
        ),
      ),
      const SizedBox(height: 16),
      if (daftar.isEmpty && tenggat.isEmpty)
        const Kartu(
          child: KeadaanKosong(
            ikon: Icons.event_busy_outlined,
            judul: 'Tidak ada jadwal di hari ini',
            pesan: 'Tidak ada kuliah atau tenggat tugas yang tercatat.',
          ),
        )
      else ...[
        // Jumlah kuliah sudah tampil di strip tanggal; tidak diulang di sini.
        // Kunci memuat tanggal: kartu beranimasi ulang saat hari diganti.
        for (final (i, p) in daftar.indexed) ...[
          Muncul(
            key: ValueKey('${_tanggal.toIso8601String()}-${p.jadwal.id}'),
            urutan: i,
            child: kartuPertemuan(
              p,
              namaMataKuliah: scope.namaMataKuliah(p.jadwal.mataKuliahId),
              mataKuliah: scope.mataKuliahDari(p.jadwal.mataKuliahId),
              hariIni: hariIni,
              onTap: onAtur == null ? null : () => onAtur(p),
            ),
          ),
          const SizedBox(height: 12),
        ],
        for (final (i, x) in tenggat.indexed) ...[
          Muncul(
            key: ValueKey('${_tanggal.toIso8601String()}-t${x.id}'),
            urutan: daftar.length + i,
            child: KartuTenggat(
              tugas: x,
              namaMataKuliah: scope.namaMataKuliah(x.mataKuliahId),
              onTap: () => bukaDetailTugas(context, x),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    ];
  }

  List<Widget> _mingguan(
    BuildContext context,
    List<Jadwal> semua,
    List<PerubahanJadwal> ubah,
    List<Tugas> tugas,
    void Function(Pertemuan)? onAtur,
  ) {
    final scope = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final akhir = _awalMinggu.add(const Duration(days: 7));
    final mingguIni = DateUtils.isSameDay(_awalMinggu, _senin(DateTime.now()));
    final tenggatMinggu = tugas
        .where(
          (x) => !x.tenggat.isBefore(_awalMinggu) && x.tenggat.isBefore(akhir),
        )
        .toList();
    final perHari = [
      for (var i = 0; i < 7; i++)
        pertemuanPada(_awalMinggu.add(Duration(days: i)), semua, ubah),
    ];
    final jumlahKuliah = perHari
        .expand((l) => l)
        .where((p) => p.berlangsung)
        .length;
    final jumlahBerubah = perHari
        .expand((l) => l)
        .where((p) => p.status != StatusPertemuan.biasa)
        .length;
    final fmt = formatHariTanggal;

    final hasil = <Widget>[
      Kartu(
        child: Column(
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Minggu sebelumnya',
                  onPressed: () => setState(
                    () => _awalMinggu = _awalMinggu.subtract(
                      const Duration(days: 7),
                    ),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        mingguIni ? 'Minggu Ini' : 'Minggu Lain',
                        style: t.titleMedium,
                      ),
                      Text(
                        '${fmt(_awalMinggu).split(', ').last} – '
                        '${fmt(akhir.subtract(const Duration(days: 1))).split(', ').last}',
                        style: t.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Minggu berikutnya',
                  onPressed: () => setState(
                    () =>
                        _awalMinggu = _awalMinggu.add(const Duration(days: 7)),
                  ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ChipStatus(
                  'Kuliah ($jumlahKuliah)',
                  jenis: JenisStatus.info,
                  titik: true,
                ),
                if (jumlahBerubah > 0)
                  ChipStatus(
                    'Perubahan ($jumlahBerubah)',
                    jenis: JenisStatus.peringatan,
                    titik: true,
                  ),
                ChipStatus(
                  'Tenggat (${tenggatMinggu.length})',
                  jenis: tenggatMinggu.isEmpty
                      ? JenisStatus.netral
                      : JenisStatus.bahaya,
                  titik: true,
                ),
                if (!mingguIni)
                  ActionChip(
                    avatar: const Icon(Icons.today, size: 16),
                    label: const Text('Ke minggu ini'),
                    onPressed: () =>
                        setState(() => _awalMinggu = _senin(DateTime.now())),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];

    var adaIsi = false;
    for (var i = 0; i < 7; i++) {
      final tgl = _awalMinggu.add(Duration(days: i));
      final kuliah = perHari[i];
      final tenggat = tenggatMinggu
          .where((x) => DateUtils.isSameDay(x.tenggat, tgl))
          .toList();
      if (kuliah.isEmpty && tenggat.isEmpty) continue;
      adaIsi = true;
      final hariIni = DateUtils.isSameDay(tgl, DateTime.now());
      final agenda = kuliah.where((p) => p.berlangsung).length + tenggat.length;
      hasil.addAll([
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: hariIni ? Warna.primerMuda : Warna.netralMuda,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (hariIni) ...[
                const Icon(
                  Icons.radio_button_checked,
                  size: 16,
                  color: Warna.primer,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  fmt(tgl).toUpperCase(),
                  style: t.labelLarge?.copyWith(
                    color: hariIni ? Warna.primer : Warna.teks,
                  ),
                ),
              ),
              Text(
                agenda == 0 ? 'Libur' : '$agenda agenda',
                style: t.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final p in kuliah) ...[
          kartuPertemuan(
            p,
            namaMataKuliah: scope.namaMataKuliah(p.jadwal.mataKuliahId),
            mataKuliah: scope.mataKuliahDari(p.jadwal.mataKuliahId),
            hariIni: hariIni,
            onTap: onAtur == null ? null : () => onAtur(p),
          ),
          const SizedBox(height: 8),
        ],
        for (final x in tenggat) ...[
          KartuTenggat(
            tugas: x,
            namaMataKuliah: scope.namaMataKuliah(x.mataKuliahId),
            onTap: () => bukaDetailTugas(context, x),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
      ]);
    }

    if (!adaIsi) {
      hasil.add(
        const Kartu(
          child: KeadaanKosong(
            ikon: Icons.calendar_month_outlined,
            judul: 'Belum ada jadwal',
            pesan: 'Jadwal kuliah yang ditambahkan admin akan tampil di sini.',
          ),
        ),
      );
    }
    // Jumlah kuliah dan tenggat sudah ada di chip ringkasan di atas.
    return hasil;
  }
}

class _Pilihan {
  const _Pilihan(
    this.ikon,
    this.judul,
    this.keterangan,
    this.aksi, {
    this.bahaya = false,
  });

  final IconData ikon;
  final String judul;
  final String keterangan;
  final VoidCallback aksi;
  final bool bahaya;
}

/// Form libur, pindah, atau kuliah tambahan untuk satu pertemuan.
class _FormPerubahan extends StatefulWidget {
  const _FormPerubahan({
    required this.scope,
    required this.jenis,
    this.sumber,
    this.awal,
    this.mataKuliahId,
    required this.tanggalAwal,
    required this.jadwal,
    required this.perubahan,
  });

  final AppScope scope;
  final JenisPerubahan jenis;

  /// Pertemuan jadwal tetap yang diubah (libur dan pindah).
  final Pertemuan? sumber;

  /// Perubahan yang sudah ada, bila sedang diedit.
  final PerubahanJadwal? awal;
  final String? mataKuliahId;
  final DateTime tanggalAwal;
  final List<Jadwal> jadwal;
  final List<PerubahanJadwal> perubahan;

  @override
  State<_FormPerubahan> createState() => _FormPerubahanState();
}

class _FormPerubahanState extends State<_FormPerubahan> {
  /// Jadwal tetap asal (libur dan pindah).
  Jadwal? get _asal => widget.sumber?.asal;

  /// Tanggal pertemuan asal yang diubah.
  DateTime? get _tanggalAsal =>
      widget.awal?.tanggalAsal ??
      (widget.sumber?.status == StatusPertemuan.pengganti
          ? widget.sumber?.perubahan?.tanggalAsal
          : widget.sumber?.tanggal);

  late String? _mk =
      widget.awal?.mataKuliahId ?? widget.mataKuliahId ?? _asal?.mataKuliahId;
  late DateTime _tanggal = tanggalSaja(
    (widget.awal?.jenis != JenisPerubahan.libur
            ? widget.awal?.tanggal
            : null) ??
        _tanggalAsal ??
        widget.tanggalAwal,
  );
  late TimeOfDay _mulai = _keJam(
    widget.awal?.jamMulai ?? _asal?.jamMulai ?? '08:00',
  );
  late TimeOfDay _selesai = _keJam(
    widget.awal?.jamSelesai ?? _asal?.jamSelesai ?? '09:40',
  );
  late final _ruang = TextEditingController(
    text: (widget.awal?.ruang.isNotEmpty ?? false)
        ? widget.awal!.ruang
        : (_asal?.ruang ?? ''),
  );
  late final _keterangan = TextEditingController(
    text: widget.awal?.keterangan ?? '',
  );
  bool _memproses = false;

  bool get _libur => widget.jenis == JenisPerubahan.libur;

  static TimeOfDay _keJam(String s) {
    final b = s.split(':');
    return TimeOfDay(hour: int.parse(b[0]), minute: int.parse(b[1]));
  }

  static String _keTeks(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _ruang.dispose();
    _keterangan.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final kini = tanggalSaja(DateTime.now());
    final pertama = _tanggal.isBefore(kini) ? _tanggal : kini;
    final hasil = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: pertama.subtract(const Duration(days: 30)),
      lastDate: kini.add(const Duration(days: 365)),
    );
    if (hasil != null) setState(() => _tanggal = tanggalSaja(hasil));
  }

  Future<void> _pilihJam(bool mulai) async {
    final hasil = await showTimePicker(
      context: context,
      initialTime: mulai ? _mulai : _selesai,
    );
    if (hasil != null) {
      setState(() => mulai ? _mulai = hasil : _selesai = hasil);
    }
  }

  Future<void> _simpan() async {
    final perubahan = PerubahanJadwal(
      id: widget.awal?.id ?? '',
      jenis: widget.jenis,
      mataKuliahId: _mk!,
      jadwalId: widget.jenis == JenisPerubahan.tambahan ? null : _asal?.id,
      tanggalAsal: widget.jenis == JenisPerubahan.tambahan
          ? null
          : _tanggalAsal,
      tanggal: _libur ? null : _tanggal,
      jamMulai: _libur ? null : _keTeks(_mulai),
      jamSelesai: _libur ? null : _keTeks(_selesai),
      ruang: _libur ? '' : _ruang.text.trim(),
      keterangan: _keterangan.text.trim(),
    );

    if (!_libur) {
      final baru = Jadwal(
        mataKuliahId: perubahan.mataKuliahId,
        hari: _tanggal.weekday,
        jamMulai: perubahan.jamMulai!,
        jamSelesai: perubahan.jamSelesai!,
        ruang: perubahan.ruang,
      );
      if (!baru.waktuValid) {
        tampilkanPesan(
          context,
          'Jam selesai harus setelah jam mulai.',
          gagal: true,
        );
        return;
      }
      if (widget.jenis == JenisPerubahan.pindah &&
          _tanggal == _tanggalAsal &&
          perubahan.jamMulai == _asal?.jamMulai &&
          perubahan.jamSelesai == _asal?.jamSelesai) {
        tampilkanPesan(
          context,
          'Pilih tanggal atau jam yang berbeda dari jadwal asal.',
          gagal: true,
        );
        return;
      }
      final bentrok = bentrokPada(
        _tanggal,
        baru,
        widget.jadwal,
        widget.perubahan,
        abaikanJadwalId: _tanggal == _tanggalAsal ? _asal?.id : null,
        abaikanPerubahanId: widget.awal?.id,
      );
      if (bentrok.isNotEmpty) {
        final lanjut = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => PeringatanBentrokPage(
              baru: baru,
              bentrok: bentrok,
              namaMataKuliah: widget.scope.namaMataKuliah,
            ),
          ),
        );
        if (lanjut != true || !mounted) return;
      }
    }

    setState(() => _memproses = true);
    try {
      await widget.scope.jadwal.simpanPerubahan(perubahan);
      if (mounted) {
        Navigator.pop(context);
        tampilkanPesan(context, switch (widget.jenis) {
          JenisPerubahan.libur => 'Pertemuan diliburkan.',
          JenisPerubahan.pindah =>
            'Pertemuan dipindah ke ${formatHariTanggal(_tanggal)}.',
          JenisPerubahan.tambahan => 'Kuliah tambahan disimpan.',
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _memproses = false);
        tampilkanPesan(context, '$e', gagal: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final asal = _asal;
    final semuaMk = widget.scope.mataKuliah;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (asal != null && _tanggalAsal != null) ...[
          KotakInfo(
            ikon: Icons.event_note_outlined,
            jenis: JenisStatus.info,
            judul: 'PERTEMUAN ASAL',
            teks:
                '${widget.scope.namaMataKuliah(asal.mataKuliahId)}\n'
                '${formatTanggalPanjang(_tanggalAsal!)}, '
                '${asal.jamMulai}–${asal.jamSelesai}'
                '${asal.ruang.isEmpty ? '' : ' • ${asal.ruang}'}',
          ),
          const SizedBox(height: 16),
        ],
        if (widget.jenis == JenisPerubahan.tambahan) ...[
          DropdownButtonFormField<String>(
            initialValue: semuaMk.any((m) => m.id == _mk) ? _mk : null,
            decoration: const InputDecoration(labelText: 'Mata kuliah'),
            items: [
              for (final m in semuaMk)
                DropdownMenuItem(value: m.id, child: Text(m.nama)),
            ],
            onChanged: (v) => setState(() => _mk = v),
          ),
          const SizedBox(height: 16),
        ],
        if (!_libur) ...[
          Text(
            widget.jenis == JenisPerubahan.pindah ? 'Pindah ke' : 'Waktu',
            style: t.labelLarge,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _memproses ? null : _pilihTanggal,
            icon: const Icon(Icons.event_outlined),
            label: Text(formatTanggalPanjang(_tanggal)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TombolJam(
                  label: 'Mulai',
                  jam: _keTeks(_mulai),
                  onTap: () => _pilihJam(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TombolJam(
                  label: 'Selesai',
                  jam: _keTeks(_selesai),
                  onTap: () => _pilihJam(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ruang,
            decoration: const InputDecoration(
              labelText: 'Ruang',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _keterangan,
          decoration: InputDecoration(
            labelText: 'Keterangan (opsional)',
            hintText: _libur
                ? 'Misalnya: dosen berhalangan, tanggal merah'
                : 'Misalnya: pengganti pertemuan yang libur',
            prefixIcon: const Icon(Icons.notes_outlined),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          style: _libur
              ? FilledButton.styleFrom(backgroundColor: Warna.peringatanTeks)
              : null,
          onPressed: _mk == null || _memproses ? null : _simpan,
          child: Text(
            _memproses
                ? 'Menyimpan…'
                : switch (widget.jenis) {
                    JenisPerubahan.libur => 'Liburkan Pertemuan',
                    JenisPerubahan.pindah => 'Simpan Pemindahan',
                    JenisPerubahan.tambahan => 'Simpan Kuliah',
                  },
          ),
        ),
      ],
    );
  }
}

class _ChipTanggal extends StatelessWidget {
  const _ChipTanggal({
    required this.tanggal,
    required this.jumlah,
    required this.dipilih,
    required this.onTap,
  });

  final DateTime tanggal;
  final int jumlah;
  final bool dipilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hariIni = DateUtils.isSameDay(tanggal, DateTime.now());
    final libur = jumlah == 0;
    // Merah hanya untuk hari Minggu (seperti kalender), bukan setiap hari
    // tanpa kuliah, agar tidak terbaca sebagai peringatan.
    final minggu = tanggal.weekday == DateTime.sunday;
    final warnaUtama = dipilih
        ? Colors.white
        : minggu
        ? Warna.bahaya
        : hariIni
        ? Warna.primer
        : libur
        ? Warna.teksSekunder
        : Warna.teks;
    final warnaKecil = dipilih ? Colors.white70 : Warna.teksSekunder;
    final radius = BorderRadius.circular(16);
    return AnimatedContainer(
      duration: Gerak.sedang,
      curve: Gerak.kurva,
      width: _JadwalPageState._lebarChip,
      decoration: BoxDecoration(
        color: dipilih ? Warna.primer : Warna.permukaan,
        borderRadius: radius,
        border: Border.all(
          color: dipilih
              ? Warna.primer
              : hariIni
              ? Warna.primer
              : Warna.garis,
        ),
        boxShadow: dipilih
            ? [
                BoxShadow(
                  color: Warna.primer.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      // Material transparan agar efek riak tampil di atas warna latar.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  formatHariSingkat(tanggal),
                  style: t.labelMedium?.copyWith(color: warnaKecil),
                ),
                Text(
                  '${tanggal.day}',
                  style: t.headlineSmall?.copyWith(
                    color: warnaUtama,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  libur ? 'Libur' : '$jumlah Kelas',
                  style: t.labelSmall?.copyWith(color: warnaKecil),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormJadwal extends StatefulWidget {
  const _FormJadwal({required this.scope, this.awal, required this.hariAwal});

  final AppScope scope;
  final Jadwal? awal;
  final int hariAwal;

  @override
  State<_FormJadwal> createState() => _FormJadwalState();
}

class _FormJadwalState extends State<_FormJadwal> {
  late String? _mk = widget.awal?.mataKuliahId;
  late int _hari = widget.awal?.hari ?? widget.hariAwal;
  late TimeOfDay _mulai = _keJam(widget.awal?.jamMulai ?? '08:00');
  late TimeOfDay _selesai = _keJam(widget.awal?.jamSelesai ?? '09:40');
  late final _ruang = TextEditingController(text: widget.awal?.ruang ?? '');
  bool _memproses = false;

  static TimeOfDay _keJam(String s) {
    final b = s.split(':');
    return TimeOfDay(hour: int.parse(b[0]), minute: int.parse(b[1]));
  }

  static String _keTeks(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _ruang.dispose();
    super.dispose();
  }

  Future<void> _pilihJam(bool mulai) async {
    final hasil = await showTimePicker(
      context: context,
      initialTime: mulai ? _mulai : _selesai,
    );
    if (hasil != null) {
      setState(() => mulai ? _mulai = hasil : _selesai = hasil);
    }
  }

  Future<void> _simpan() async {
    final jadwal = Jadwal(
      id: widget.awal?.id ?? '',
      mataKuliahId: _mk!,
      hari: _hari,
      jamMulai: _keTeks(_mulai),
      jamSelesai: _keTeks(_selesai),
      ruang: _ruang.text.trim(),
    );
    if (!jadwal.waktuValid) {
      tampilkanPesan(
        context,
        'Jam selesai harus setelah jam mulai.',
        gagal: true,
      );
      return;
    }
    setState(() => _memproses = true);
    try {
      final repo = widget.scope.jadwal;
      final bentrok = await repo.cariBentrok(jadwal);
      if (bentrok.isNotEmpty && mounted) {
        final lanjut = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => PeringatanBentrokPage(
              baru: jadwal,
              bentrok: bentrok,
              namaMataKuliah: widget.scope.namaMataKuliah,
            ),
          ),
        );
        if (lanjut != true) {
          if (mounted) setState(() => _memproses = false);
          return;
        }
      }
      await repo.simpan(jadwal);
      if (mounted) {
        Navigator.pop(context);
        tampilkanPesan(context, 'Jadwal disimpan.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _memproses = false);
        tampilkanPesan(context, 'Gagal menyimpan jadwal: $e', gagal: true);
      }
    }
  }

  Future<void> _hapus() async {
    final ya = await konfirmasi(
      context,
      ikon: Icons.delete_outline,
      judul: 'Hapus jadwal ini?',
      pesan: 'Jadwal hilang dari tampilan semua anggota kelas.',
      tombolYa: 'Hapus',
      bahaya: true,
    );
    if (!ya || !mounted) return;
    setState(() => _memproses = true);
    await widget.scope.jadwal.hapus(widget.awal!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final mk = widget.scope.mataKuliah;
    final t = Theme.of(context).textTheme;
    if (mk.isEmpty) {
      return const KeadaanKosong(
        ikon: Icons.menu_book_outlined,
        judul: 'Belum ada mata kuliah',
        pesan: 'Tambahkan di Profil → Kelola mata kuliah.',
        ringkas: true,
      );
    }
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
        Text('Hari', style: t.labelLarge),
        const SizedBox(height: 8),
        // Tujuh hari dalam satu baris dengan lebar sama.
        Row(
          children: [
            for (var h = 1; h <= 7; h++) ...[
              if (h > 1) const SizedBox(width: 6),
              Expanded(
                child: _PilihHari(
                  label: Jadwal.daftarHari[h - 1].substring(0, 3),
                  dipilih: _hari == h,
                  onTap: () => setState(() => _hari = h),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _TombolJam(
                label: 'Mulai',
                jam: _keTeks(_mulai),
                onTap: () => _pilihJam(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TombolJam(
                label: 'Selesai',
                jam: _keTeks(_selesai),
                onTap: () => _pilihJam(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _ruang,
          decoration: const InputDecoration(
            labelText: 'Ruang',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _mk == null || _memproses ? null : _simpan,
          child: Text(_memproses ? 'Menyimpan…' : 'Simpan Jadwal'),
        ),
        if (widget.awal != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _memproses ? null : _hapus,
            style: TextButton.styleFrom(foregroundColor: Warna.bahaya),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Hapus Jadwal'),
          ),
        ],
      ],
    );
  }
}

class _TombolJam extends StatelessWidget {
  const _TombolJam({
    required this.label,
    required this.jam,
    required this.onTap,
  });

  final String label;
  final String jam;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Warna.garis),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule, color: Warna.primer),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.bodySmall),
                Text(jam, style: t.titleMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Halaman peringatan bentrok (desain 7e). Mengembalikan `true` bila admin
/// memilih tetap menyimpan.
class PeringatanBentrokPage extends StatelessWidget {
  const PeringatanBentrokPage({
    super.key,
    required this.baru,
    required this.bentrok,
    required this.namaMataKuliah,
  });

  final Jadwal baru;
  final List<Jadwal> bentrok;
  final String Function(String id) namaMataKuliah;

  int _tumpang(Jadwal a, Jadwal b) {
    final mulai = a.menitMulai > b.menitMulai ? a.menitMulai : b.menitMulai;
    final selesai = a.menitSelesai < b.menitSelesai
        ? a.menitSelesai
        : b.menitSelesai;
    return selesai - mulai;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final menit = bentrok
        .map((b) => _tumpang(baru, b))
        .reduce((a, b) => a > b ? a : b);

    Widget kartu(Jadwal j, {required bool lama}) => Kartu(
      strip: lama ? Warna.bahaya : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChipStatus(
            lama ? 'Jadwal tersimpan' : 'Jadwal baru',
            jenis: lama ? JenisStatus.netral : JenisStatus.info,
          ),
          const SizedBox(height: 8),
          Text(namaMataKuliah(j.mataKuliahId), style: t.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: KotakInfo(
                  ikon: Icons.schedule,
                  jenis: lama ? JenisStatus.bahaya : JenisStatus.info,
                  judul: 'Waktu',
                  teks: '${j.namaHari}, ${j.jamMulai}–${j.jamSelesai}',
                ),
              ),
              if (j.ruang.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: KotakInfo(
                    ikon: Icons.meeting_room_outlined,
                    jenis: lama ? JenisStatus.bahaya : JenisStatus.info,
                    judul: 'Ruang',
                    teks: j.ruang,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Konfirmasi Jadwal')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('Peringatan Bentrok Jadwal', style: t.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Jadwal yang kamu masukkan bertabrakan dengan jadwal lain yang sudah tersimpan.',
            style: t.bodyMedium?.copyWith(color: Warna.teksSekunder),
          ),
          const SizedBox(height: 16),
          const KotakInfo(
            jenis: JenisStatus.bahaya,
            ikon: Icons.warning_amber_rounded,
            judul: 'Terjadi bentrok waktu',
            teks: 'Anggota kelas tidak bisa mengikuti dua kuliah pada waktu yang sama.',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text('Perbandingan jadwal', style: t.titleMedium),
              ),
              ChipStatus(
                'Tumpang tindih ${formatLamaMenit(menit)}',
                jenis: JenisStatus.bahaya,
              ),
            ],
          ),
          const SizedBox(height: 12),
          kartu(baru, lama: false),
          const SizedBox(height: 12),
          for (final b in bentrok) ...[
            kartu(b, lama: true),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Ubah Waktu atau Ruang'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Warna.bahaya),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.warning_amber_rounded),
            label: const Text('Tetap Simpan (Paksa Bentrok)'),
          ),
        ],
      ),
    );
  }
}

class _PilihHari extends StatelessWidget {
  const _PilihHari({
    required this.label,
    required this.dipilih,
    required this.onTap,
  });

  final String label;
  final bool dipilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return AnimatedContainer(
      duration: Gerak.sedang,
      curve: Gerak.kurva,
      height: 44,
      decoration: BoxDecoration(
        color: dipilih ? Warna.primer : Warna.permukaan,
        borderRadius: radius,
        border: Border.all(color: dipilih ? Warna.primer : Warna.garis),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: dipilih ? Colors.white : Warna.teks),
            ),
          ),
        ),
      ),
    );
  }
}
