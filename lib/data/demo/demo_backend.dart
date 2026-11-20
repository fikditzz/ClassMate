import 'dart:async';

import '../../core/errors.dart';
import '../../models/akun.dart';
import '../../models/jadwal.dart';
import '../../models/kas.dart';
import '../../models/kehadiran.dart';
import '../../models/mata_kuliah.dart';
import '../../models/pengguna.dart';
import '../../models/pengumpulan.dart';
import '../../models/pengumuman.dart';
import '../../models/rekap.dart';
import '../../models/rekap_kehadiran.dart';
import '../../models/perubahan_jadwal.dart';
import '../../models/sesi_absensi.dart';
import '../../models/tugas.dart';
import '../../repositories/absensi_repository.dart';
import '../../repositories/akun_repository.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/jadwal_repository.dart';
import '../../repositories/kas_repository.dart';
import '../../repositories/pengumuman_repository.dart';
import '../../repositories/rekap_repository.dart';
import '../../repositories/penyimpanan_berkas.dart';
import '../../repositories/tugas_repository.dart';
import '../backend.dart';
import 'jadwal_tekom_a_2025.dart';

/// Backend contoh di memori. Dipakai saat Supabase belum dikonfigurasi,
/// atau dengan `--dart-define=DEMO=true`, dan untuk pengujian.
/// Data hilang saat aplikasi ditutup.
class DemoBackend implements BackendClassMate {
  DemoBackend({DateTime? sekarang})
    : _data = _DataDemo(sekarang ?? DateTime.now());

  final _DataDemo _data;

  @override
  late final DemoAuthRepository auth = DemoAuthRepository();

  @override
  bool get modeDemo => true;

  @override
  RepositoriPengguna buatRepositori(Pengguna pengguna) => RepositoriPengguna(
    absensi: _DemoAbsensi(_data, pengguna),
    tugas: _DemoTugas(_data, pengguna),
    jadwal: _DemoJadwal(_data),
    akun: _DemoAkun(_data, pengguna),
    kas: _DemoKas(_data, pengguna),
    pengumuman: _DemoPengumuman(_data, pengguna),
    rekap: _DemoRekap(_data, pengguna),
  );
}

/// Nilai yang bisa diamati: stream langsung mengirim nilai terkini.
class _Nilai<T> {
  _Nilai(this._v);

  T _v;
  final _c = StreamController<T>.broadcast();

  T get v => _v;
  set v(T baru) {
    _v = baru;
    _c.add(baru);
  }

  Stream<T> get aliran async* {
    yield _v;
    yield* _c.stream;
  }
}

class DemoAuthRepository implements AuthRepository {
  final _pengguna = _Nilai<Pengguna?>(null);

  @override
  Stream<Pengguna?> get perubahanPengguna => _pengguna.aliran;

  @override
  Future<Pengguna> masuk() => masukSebagai(admin: false);

  Future<Pengguna> masukSebagai({required bool admin}) async {
    final p = Pengguna.dariData(
      uid: admin ? 'demo-admin' : 'demo-anggota',
      email: admin ? 'ketua@kelas.demo' : 'mahasiswa@kelas.demo',
      data: {
        'nama': admin ? 'Raka Pratama' : 'Sinta Maharani',
        'username': admin ? 'raka.ketua' : 'sinta',
        'peran': admin ? 'admin' : 'anggota',
        'kelas_id': kelasTekomA2025,
      },
    );
    _pengguna.v = p;
    return p;
  }

  @override
  Future<void> keluar() async => _pengguna.v = null;

  /// Mode demo tidak menyimpan password; hanya aturan isiannya yang diperiksa.
  @override
  Future<void> gantiPassword(String lama, String baru) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (lama.isEmpty) throw const ClassMateException('Isi password lama.');
    if (baru.length < AkunRepository.panjangPassword) {
      throw const ClassMateException(
        'Password baru minimal ${AkunRepository.panjangPassword} karakter.',
      );
    }
    if (baru == lama) {
      throw const ClassMateException(
        'Password baru harus berbeda dari password lama.',
      );
    }
  }
}

class _DataDemo {
  _DataDemo(DateTime t) {
    mataKuliah = _Nilai(mataKuliahTekomA2025);
    jadwal = _Nilai(jadwalTekomA2025);

    // Sesi contoh untuk mata kuliah hari ini; bila hari ini tidak ada kuliah
    // (misalnya Minggu), pakai mata kuliah pertama.
    final mkHariIni = jadwalTekomA2025
        .where((j) => j.hari == t.weekday)
        .firstOrNull;
    sesi = _Nilai([
      SesiAbsensi(
        id: 's1',
        mataKuliahId: mkHariIni?.mataKuliahId ?? 'pweb',
        mulai: t.subtract(const Duration(minutes: 5)),
        berakhir: t.add(const Duration(minutes: 25)),
        status: 'buka',
      ),
    ]);
    token['s1'] = 'KLS123';
    tugas = _Nilai([
      Tugas(
        id: 't1',
        mataKuliahId: 'pweb',
        judul: 'Landing page responsif',
        deskripsi:
            'Buat landing page satu halaman dengan HTML dan CSS yang rapi di '
            'layar ponsel dan desktop. Kumpulkan dalam bentuk ZIP.',
        tenggat: t.add(const Duration(hours: 20)),
      ),
      Tugas(
        id: 't2',
        mataKuliahId: 'mdk',
        judul: 'Latihan relasi dan fungsi',
        deskripsi: 'Kerjakan soal nomor 1–10 bab relasi dan fungsi.',
        tenggat: t.add(const Duration(days: 3, hours: 2)),
      ),
      Tugas(
        id: 't3',
        mataKuliahId: 'dap',
        judul: 'Wireframe aplikasi kampus',
        deskripsi: 'Rancang wireframe 5 layar utama, kumpulkan dalam PDF.',
        tenggat: t.add(const Duration(days: 9)),
      ),
    ]);
    _isiKasDanPengumuman(t);
  }

  /// Iuran Rp10.000 per pekan sejak 8 pekan lalu (Senin), beberapa
  /// pemasukan/pengeluaran, dan dua pengumuman.
  void _isiKasDanPengumuman(DateTime t) {
    final hariIni = DateTime(t.year, t.month, t.day);
    final seninIni = hariIni.subtract(Duration(days: hariIni.weekday - 1));
    final mulai = seninIni.subtract(const Duration(days: 7 * 7));
    aturanIuran = AturanIuran(nominal: 10000, mulai: mulai);

    final daftar = <TransaksiKas>[];
    var n = 0;
    void iuran(String uid, int pekan) {
      for (var i = 0; i < pekan; i++) {
        daftar.add(
          TransaksiKas(
            id: 'kas-${n++}',
            jenis: JenisKas.iuran,
            jumlah: 10000,
            tanggal: mulai.add(Duration(days: 7 * i + 1)),
            keterangan: 'Iuran pekan ${i + 1}',
            userId: uid,
          ),
        );
      }
    }

    iuran('demo-admin', 8);
    iuran('demo-anggota', 6);
    iuran('demo-anggota-2', 4);
    daftar.addAll([
      TransaksiKas(
        id: 'kas-${n++}',
        jenis: JenisKas.pemasukan,
        jumlah: 150000,
        tanggal: hariIni.subtract(const Duration(days: 20)),
        keterangan: 'Sisa dana makrab angkatan',
      ),
      TransaksiKas(
        id: 'kas-${n++}',
        jenis: JenisKas.pengeluaran,
        jumlah: 32000,
        tanggal: hariIni.subtract(const Duration(days: 10)),
        keterangan: 'Spidol dan penghapus papan',
      ),
      TransaksiKas(
        id: 'kas-${n++}',
        jenis: JenisKas.pengeluaran,
        jumlah: 45000,
        tanggal: hariIni.subtract(const Duration(days: 6)),
        keterangan: 'Print modul praktikum Pemrograman Web',
      ),
      TransaksiKas(
        id: 'kas-${n++}',
        jenis: JenisKas.pengeluaran,
        jumlah: 60000,
        tanggal: hariIni.subtract(const Duration(days: 1)),
        keterangan: 'Konsumsi kerja kelompok DAP',
      ),
    ]);
    kas = _Nilai(daftar);

    pengumuman = _Nilai([
      Pengumuman(
        id: 'p1',
        judul: 'Kuis Matematika Diskrit pekan depan',
        isi:
            'Materi relasi dan fungsi. Bawa kalkulator dan kartu mahasiswa. '
            'Kuis dimulai tepat 14:50 di AE 109.',
        penting: true,
        namaPembuat: 'Raka Pratama',
        dibuatPada: t.subtract(const Duration(hours: 5)),
      ),
      Pengumuman(
        id: 'p2',
        judul: 'Iuran kas pekan ini',
        isi:
            'Iuran Rp10.000 bisa dibayar ke bendahara sampai Jumat. '
            'Riwayat dan saldo kas bisa dilihat di menu Uang Kas.',
        namaPembuat: 'Raka Pratama',
        dibuatPada: t.subtract(const Duration(days: 3)),
      ),
    ]);
  }

  late AturanIuran? aturanIuran;
  late final _Nilai<List<TransaksiKas>> kas;
  late final _Nilai<List<Pengumuman>> pengumuman;
  late final _Nilai<List<MataKuliah>> mataKuliah;
  late final _Nilai<List<Jadwal>> jadwal;
  late final _Nilai<List<SesiAbsensi>> sesi;
  late final _Nilai<List<Tugas>> tugas;
  final token = <String, String>{};
  final kehadiran = _Nilai<List<Kehadiran>>([]);
  final perubahan = _Nilai<List<PerubahanJadwal>>([]);
  final akun = _Nilai<List<Akun>>(const [
    Akun(
      id: 'demo-admin',
      nama: 'Raka Pratama',
      username: 'raka.ketua',
      email: 'ketua@kelas.demo',
      peran: 'admin',
      punyaLogin: true,
    ),
    Akun(
      id: 'demo-anggota',
      nama: 'Sinta Maharani',
      username: 'sinta',
      email: 'mahasiswa@kelas.demo',
      peran: 'mahasiswa',
      punyaLogin: true,
    ),
    Akun(
      id: 'demo-anggota-2',
      nama: 'Bima Saputra',
      username: 'bima',
      email: 'bima@kelas.demo',
      peran: 'mahasiswa',
    ),
  ]);
  final pengumpulan = _Nilai<List<Pengumpulan>>([]);
  var _urut = 0;

  String idBaru(String awalan) => '$awalan-demo-${_urut++}';

  /// Riwayat sesi contoh: tiap jadwal sampai [pekanRiwayat] pekan ke
  /// belakang (yang sudah dimulai).
  static const pekanRiwayat = 10;

  List<_SesiRiwayat> riwayatSesi(DateTime sekarang) {
    final hariIni = DateTime(sekarang.year, sekarang.month, sekarang.day);
    final hasil = <_SesiRiwayat>[];
    for (final j in jadwal.v) {
      for (var i = 1; i <= pekanRiwayat; i++) {
        final tgl = hariIni.subtract(
          Duration(days: (hariIni.weekday - j.hari) % 7 + 7 * (i - 1)),
        );
        final mulai = tgl.add(Duration(minutes: j.menitMulai));
        if (mulai.isAfter(sekarang)) continue;
        hasil.add(_SesiRiwayat('riwayat-${j.id}-$i', j.mataKuliahId, mulai, i));
      }
    }
    return hasil;
  }

  /// Pola hadir contoh yang tetap: sesekali tidak hadir.
  static bool hadirRiwayat(_SesiRiwayat r, String uid) {
    var h = 0;
    for (final c in uid.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return (r.pekan + r.mataKuliahId.length + h) % 6 != 0;
  }

  /// Mahasiswa contoh tambahan (fiktif) agar dokumen rekap terisi.
  static const mahasiswaFiktif = [
    'Adinda Putri Lestari',
    'Ahmad Fauzan',
    'Aulia Rahmawati',
    'Bayu Firmansyah',
    'Citra Ayuningtyas',
    'Dimas Prasetyo',
    'Fadhil Ramadhan',
    'Gita Permatasari',
    'Hendra Kurniawan',
    'Intan Nurhaliza',
    'Kevin Wijaya',
    'Laras Sekarwati',
    'Muhammad Rizky',
    'Nabila Azzahra',
    'Putra Mahendra',
    'Rina Oktaviani',
    'Yusuf Habibi',
  ];
}

class _SesiRiwayat {
  const _SesiRiwayat(this.id, this.mataKuliahId, this.mulai, this.pekan);

  final String id;
  final String mataKuliahId;
  final DateTime mulai;
  final int pekan;
}

class _DemoAbsensi implements AbsensiRepository {
  _DemoAbsensi(this._d, this._p);

  final _DataDemo _d;
  final Pengguna _p;

  @override
  Stream<List<SesiAbsensi>> sesiAktif() => _d.sesi.aliran.map(
    (l) => l.where((s) => s.keFirestore()['status'] == 'buka').toList(),
  );

  @override
  Stream<Set<String>> sesiYangSudahDihadiri() => _d.kehadiran.aliran.map(
    (l) => l.where((k) => k.uid == _p.uid).map((k) => k.sesiId).toSet(),
  );

  @override
  Future<RekapKehadiran> rekapKehadiranSaya() async {
    final sekarang = DateTime.now();
    final perSesi = <String, String>{};
    final hadir = <String>{};
    for (final r in _d.riwayatSesi(sekarang)) {
      perSesi[r.id] = r.mataKuliahId;
      if (_DataDemo.hadirRiwayat(r, _p.uid)) hadir.add(r.id);
    }
    for (final s in _d.sesi.v) {
      if (!s.mulai.isAfter(sekarang)) perSesi[s.id] = s.mataKuliahId;
    }
    hadir.addAll(
      _d.kehadiran.v.where((k) => k.uid == _p.uid).map((k) => k.sesiId),
    );
    return RekapKehadiran.hitung(
      mataKuliahPerSesi: perSesi,
      sesiDihadiri: hadir,
    );
  }

  @override
  Future<void> hadir(String sesiId, String token) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (_d.kehadiran.v.any((k) => k.sesiId == sesiId && k.uid == _p.uid)) {
      throw const ClassMateException('Kamu sudah absen di sesi ini.');
    }
    final sesi = _d.sesi.v.where((s) => s.id == sesiId).firstOrNull;
    if (sesi == null ||
        !sesi.masihBerlaku() ||
        _d.token[sesiId] != token.trim().toUpperCase()) {
      throw const ClassMateException('Token salah atau sesi sudah berakhir.');
    }
    _d.kehadiran.v = [
      ..._d.kehadiran.v,
      Kehadiran(
        sesiId: sesiId,
        uid: _p.uid,
        email: _p.email,
        waktuAbsen: DateTime.now(),
      ),
    ];
  }

  @override
  Future<String> buatSesi({
    required String mataKuliahId,
    required DateTime mulai,
    required DateTime berakhir,
  }) async {
    final id = _d.idBaru('sesi');
    final token = AbsensiRepository.buatToken();
    _d.token[id] = token;
    _d.sesi.v = [
      ..._d.sesi.v,
      SesiAbsensi(
        id: id,
        mataKuliahId: mataKuliahId,
        mulai: mulai,
        berakhir: berakhir,
        status: 'buka',
      ),
    ];
    return token;
  }

  @override
  Future<String> tokenSesi(String sesiId) async => _d.token[sesiId] ?? '-';

  @override
  Future<void> tutupSesi(String sesiId) async {
    _d.sesi.v = [
      for (final s in _d.sesi.v)
        s.id == sesiId
            ? SesiAbsensi(
                id: s.id,
                mataKuliahId: s.mataKuliahId,
                mulai: s.mulai,
                berakhir: s.berakhir,
                status: 'tutup',
              )
            : s,
    ];
  }

  @override
  Stream<List<Kehadiran>> rekapSesi(String sesiId) => _d.kehadiran.aliran.map(
    (l) => l.where((k) => k.sesiId == sesiId).toList(),
  );
}

class _DemoTugas implements TugasRepository {
  _DemoTugas(this._d, this._p);

  final _DataDemo _d;
  final Pengguna _p;

  @override
  Stream<List<Tugas>> daftarTugas() => _d.tugas.aliran.map(
    (l) => [...l]..sort((a, b) => a.tenggat.compareTo(b.tenggat)),
  );

  @override
  Stream<Map<String, Pengumpulan>> pengumpulanSaya() =>
      _d.pengumpulan.aliran.map(
        (l) => {for (final p in l.where((p) => p.uid == _p.uid)) p.tugasId: p},
      );

  @override
  Future<void> catatPengumpulan(Tugas tugas, BerkasTerunggah berkas) async {
    if (tugas.sudahLewatTenggat()) {
      throw const ClassMateException('Tenggat tugas ini sudah lewat.');
    }
    _d.pengumpulan.v = [
      ..._d.pengumpulan.v.where(
        (p) => !(p.tugasId == tugas.id && p.uid == _p.uid),
      ),
      Pengumpulan(
        tugasId: tugas.id,
        uid: _p.uid,
        email: _p.email,
        driveFileId: berkas.fileId,
        driveUrl: berkas.url,
        namaFile: berkas.nama,
        ukuran: berkas.ukuran,
        waktuUpload: DateTime.now(),
      ),
    ];
  }

  @override
  Future<void> buatTugas(Tugas tugas) async {
    _d.tugas.v = [
      ..._d.tugas.v,
      Tugas(
        id: _d.idBaru('tugas'),
        mataKuliahId: tugas.mataKuliahId,
        judul: tugas.judul,
        deskripsi: tugas.deskripsi,
        tenggat: tugas.tenggat,
        dibuatOleh: _p.email,
      ),
    ];
  }

  @override
  Future<void> ubahTugas(Tugas tugas) async {
    _d.tugas.v = [
      for (final t in _d.tugas.v)
        t.id == tugas.id
            ? Tugas(
                id: t.id,
                mataKuliahId: tugas.mataKuliahId,
                judul: tugas.judul,
                deskripsi: tugas.deskripsi,
                tenggat: tugas.tenggat,
                dibuatOleh: t.dibuatOleh,
              )
            : t,
    ];
  }

  @override
  Future<void> hapusTugas(String id) async {
    _d.tugas.v = _d.tugas.v.where((t) => t.id != id).toList();
    _d.pengumpulan.v = _d.pengumpulan.v.where((p) => p.tugasId != id).toList();
  }

  @override
  Stream<List<Pengumpulan>> pengumpulanTugas(String tugasId) => _d
      .pengumpulan
      .aliran
      .map((l) => l.where((p) => p.tugasId == tugasId).toList());
}

class _DemoJadwal implements JadwalRepository {
  _DemoJadwal(this._d);

  final _DataDemo _d;

  @override
  Stream<List<Jadwal>> semuaJadwal() =>
      _d.jadwal.aliran.map((l) => [...l]..sort((a, b) => a.bandingkan(b)));

  @override
  Stream<List<MataKuliah>> mataKuliah() => _d.mataKuliah.aliran;

  @override
  Stream<List<PerubahanJadwal>> perubahanJadwal() => _d.perubahan.aliran;

  @override
  Future<void> simpanMataKuliah(MataKuliah mataKuliah) async {
    final nama = mataKuliah.nama.trim().toLowerCase();
    if (_d.mataKuliah.v.any(
      (m) => m.id != mataKuliah.id && m.nama.toLowerCase() == nama,
    )) {
      throw const ClassMateException('Mata kuliah dengan nama ini sudah ada.');
    }
    final baru = MataKuliah(
      id: mataKuliah.id.isEmpty ? _d.idBaru('mk') : mataKuliah.id,
      nama: mataKuliah.nama.trim(),
      kelasId: kelasTekomA2025,
      kode: mataKuliah.kode.trim(),
      sks: mataKuliah.sks,
      dosen: [
        for (final x in mataKuliah.dosen)
          if (x.trim().isNotEmpty) x.trim(),
      ],
    );
    _d.mataKuliah.v = mataKuliah.id.isEmpty
        ? [..._d.mataKuliah.v, baru]
        : [for (final m in _d.mataKuliah.v) m.id == baru.id ? baru : m];
  }

  @override
  Future<void> hapusMataKuliah(String id) async {
    final jadwalTerhapus = {
      for (final j in _d.jadwal.v)
        if (j.mataKuliahId == id) j.id,
    };
    _d.mataKuliah.v = _d.mataKuliah.v.where((m) => m.id != id).toList();
    _d.jadwal.v = _d.jadwal.v.where((j) => j.mataKuliahId != id).toList();
    _d.tugas.v = _d.tugas.v.where((t) => t.mataKuliahId != id).toList();
    _d.sesi.v = _d.sesi.v.where((s) => s.mataKuliahId != id).toList();
    _d.perubahan.v = _d.perubahan.v
        .where(
          (p) => p.mataKuliahId != id && !jadwalTerhapus.contains(p.jadwalId),
        )
        .toList();
  }

  @override
  Future<void> simpanPerubahan(PerubahanJadwal perubahan) async {
    if (perubahan.jadwalId != null &&
        _d.perubahan.v.any(
          (p) =>
              p.id != perubahan.id &&
              p.jadwalId == perubahan.jadwalId &&
              p.tanggalAsal == perubahan.tanggalAsal,
        )) {
      throw const ClassMateException(
        'Pertemuan ini sudah punya perubahan. Batalkan dulu yang lama.',
      );
    }
    final baru = PerubahanJadwal(
      id: perubahan.id.isEmpty ? _d.idBaru('ubah') : perubahan.id,
      jenis: perubahan.jenis,
      mataKuliahId: perubahan.mataKuliahId,
      jadwalId: perubahan.jadwalId,
      tanggalAsal: perubahan.tanggalAsal,
      tanggal: perubahan.tanggal,
      jamMulai: perubahan.jamMulai,
      jamSelesai: perubahan.jamSelesai,
      ruang: perubahan.ruang,
      keterangan: perubahan.keterangan,
    );
    _d.perubahan.v = perubahan.id.isEmpty
        ? [..._d.perubahan.v, baru]
        : [for (final p in _d.perubahan.v) p.id == baru.id ? baru : p];
  }

  @override
  Future<void> hapusPerubahan(String id) async =>
      _d.perubahan.v = _d.perubahan.v.where((p) => p.id != id).toList();

  @override
  Future<List<Jadwal>> cariBentrok(Jadwal jadwal) async =>
      _d.jadwal.v.where(jadwal.bentrokDengan).toList();

  @override
  Future<void> simpan(Jadwal jadwal) async {
    if (jadwal.id.isEmpty) {
      _d.jadwal.v = [..._d.jadwal.v, jadwal.salin(id: _d.idBaru('jadwal'))];
    } else {
      _d.jadwal.v = [
        for (final j in _d.jadwal.v) j.id == jadwal.id ? jadwal : j,
      ];
    }
  }

  @override
  Future<void> hapus(String id) async {
    _d.jadwal.v = _d.jadwal.v.where((j) => j.id != id).toList();
    _d.perubahan.v = _d.perubahan.v.where((p) => p.jadwalId != id).toList();
  }
}

class _DemoAkun implements AkunRepository {
  _DemoAkun(this._d, this._p);

  final _DataDemo _d;
  final Pengguna _p;

  void _cekAdmin() {
    if (!_p.bolehKelolaAkun) {
      throw const ClassMateException(
        'Hanya admin kelas yang boleh mengelola akun.',
      );
    }
  }

  void _cekUnik(Akun akun) {
    for (final a in _d.akun.v.where((a) => a.id != akun.id)) {
      if (a.email == akun.email.trim().toLowerCase()) {
        throw const ClassMateException('Email sudah terdaftar.');
      }
      if (a.username == akun.username.trim().toLowerCase()) {
        throw const ClassMateException('Username sudah dipakai akun lain.');
      }
    }
  }

  static void _cekPassword(String pw) {
    if (pw.length < AkunRepository.panjangPassword) {
      throw const ClassMateException(
        'Password minimal ${AkunRepository.panjangPassword} karakter.',
      );
    }
  }

  @override
  Future<List<Akun>> daftarAkun() async {
    _cekAdmin();
    return [..._d.akun.v]..sort((a, b) => a.nama.compareTo(b.nama));
  }

  @override
  Future<void> buatAkun(Akun akun, String password) async {
    _cekAdmin();
    _cekPassword(password);
    _cekUnik(akun);
    _d.akun.v = [
      ..._d.akun.v,
      Akun(
        id: _d.idBaru('akun'),
        nama: akun.nama.trim(),
        username: akun.username.trim().toLowerCase(),
        email: akun.email.trim().toLowerCase(),
        peran: akun.peran,
        punyaLogin: true,
      ),
    ];
  }

  @override
  Future<void> ubahAkun(Akun akun) async {
    _cekAdmin();
    _cekUnik(akun);
    if (akun.id == _p.uid && akun.peran != 'admin') {
      throw const ClassMateException(
        'Kamu tidak bisa menurunkan peranmu sendiri.',
      );
    }
    _d.akun.v = [
      for (final a in _d.akun.v)
        a.id == akun.id
            ? akun.salin(
                nama: akun.nama.trim(),
                username: akun.username.trim().toLowerCase(),
                email: akun.email.trim().toLowerCase(),
              )
            : a,
    ];
  }

  @override
  Future<void> aturPassword(String id, String passwordBaru) async {
    _cekAdmin();
    _cekPassword(passwordBaru);
    _d.akun.v = [
      for (final a in _d.akun.v)
        a.id == id
            ? Akun(
                id: a.id,
                nama: a.nama,
                username: a.username,
                email: a.email,
                peran: a.peran,
                punyaLogin: true,
                loginTerakhir: a.loginTerakhir,
              )
            : a,
    ];
  }

  @override
  Future<void> hapusAkun(String id) async {
    _cekAdmin();
    if (id == _p.uid) {
      throw const ClassMateException(
        'Kamu tidak bisa menghapus akunmu sendiri.',
      );
    }
    _d.akun.v = _d.akun.v.where((a) => a.id != id).toList();
  }
}

class _DemoKas implements KasRepository {
  _DemoKas(this._d, this._p);

  final _DataDemo _d;
  final Pengguna _p;

  void _cekAdmin() {
    if (!_p.bolehKelolaAkun) {
      throw const ClassMateException('Hanya admin kelas yang mengelola kas.');
    }
  }

  @override
  Future<RingkasanKas> ringkasan() async =>
      RingkasanKas.dariTransaksi(_d.kas.v, aturan: _d.aturanIuran);

  @override
  Future<List<TransaksiKas>> riwayatKelas() async {
    final nama = {for (final a in _d.akun.v) a.id: a.nama};
    final hasil = <TransaksiKas>[];
    if (_p.bolehKelolaAkun) {
      for (final t in _d.kas.v) {
        hasil.add(
          TransaksiKas(
            id: t.id,
            jenis: t.jenis,
            jumlah: t.jumlah,
            tanggal: t.tanggal,
            keterangan: t.keterangan,
            userId: t.userId,
            namaAnggota: nama[t.userId],
          ),
        );
      }
    } else {
      // Iuran orang lain digabung per tanggal tanpa nama.
      final iuranPerTanggal = <DateTime, (int, int)>{};
      for (final t in _d.kas.v) {
        if (t.jenis == JenisKas.iuran) {
          final k = DateTime(t.tanggal.year, t.tanggal.month, t.tanggal.day);
          final (jml, n) = iuranPerTanggal[k] ?? (0, 0);
          iuranPerTanggal[k] = (jml + t.jumlah, n + 1);
        } else {
          hasil.add(t);
        }
      }
      iuranPerTanggal.forEach((tgl, v) {
        hasil.add(
          TransaksiKas(
            jenis: JenisKas.iuran,
            jumlah: v.$1,
            tanggal: tgl,
            keterangan: 'Iuran kas',
            jumlahAnggota: v.$2,
          ),
        );
      });
    }
    return hasil..sort((a, b) => b.tanggal.compareTo(a.tanggal));
  }

  @override
  Future<List<TransaksiKas>> iuranSaya() async =>
      _d.kas.v
          .where((t) => t.jenis == JenisKas.iuran && t.userId == _p.uid)
          .toList()
        ..sort((a, b) => b.tanggal.compareTo(a.tanggal));

  @override
  Future<void> simpan(TransaksiKas t) async {
    _cekAdmin();
    if (t.jumlah <= 0) {
      throw const ClassMateException('Nominal harus lebih dari 0.');
    }
    if (t.jenis == JenisKas.iuran && t.userId == null) {
      throw const ClassMateException('Pilih anggota yang membayar iuran.');
    }
    final baru = TransaksiKas(
      id: t.id.isEmpty ? _d.idBaru('kas') : t.id,
      jenis: t.jenis,
      jumlah: t.jumlah,
      tanggal: t.tanggal,
      keterangan: t.keterangan.trim(),
      userId: t.jenis == JenisKas.iuran ? t.userId : null,
    );
    _d.kas.v = [
      for (final x in _d.kas.v)
        if (x.id != baru.id) x,
      baru,
    ];
  }

  @override
  Future<void> hapus(String id) async {
    _cekAdmin();
    _d.kas.v = _d.kas.v.where((t) => t.id != id).toList();
  }

  @override
  Future<List<StatusIuran>> statusIuran() async {
    _cekAdmin();
    final hasil = <StatusIuran>[];
    for (final a in _d.akun.v) {
      if (a.peran == 'dosen') continue;
      final milik = _d.kas.v
          .where((t) => t.jenis == JenisKas.iuran && t.userId == a.id)
          .toList();
      final tanggal = milik.map((t) => t.tanggal).toList()..sort();
      hasil.add(
        StatusIuran(
          userId: a.id,
          nama: a.nama,
          totalBayar: milik.fold(0, (s, t) => s + t.jumlah),
          kaliBayar: milik.length,
          terakhir: tanggal.isEmpty ? null : tanggal.last,
        ),
      );
    }
    return hasil..sort((a, b) => a.nama.compareTo(b.nama));
  }

  @override
  Future<void> aturIuran(AturanIuran aturan) async {
    _cekAdmin();
    if (aturan.nominal <= 0) {
      throw const ClassMateException('Nominal iuran harus lebih dari 0.');
    }
    _d.aturanIuran = aturan;
  }
}

class _DemoPengumuman implements PengumumanRepository {
  _DemoPengumuman(this._d, this._p);

  final _DataDemo _d;
  final Pengguna _p;

  @override
  Future<List<Pengumuman>> daftar() async =>
      [..._d.pengumuman.v]
        ..sort((a, b) => b.dibuatPada.compareTo(a.dibuatPada));

  @override
  Future<void> simpan(Pengumuman p) async {
    if (!_p.isAdmin) {
      throw const ClassMateException(
        'Hanya admin dan dosen yang membuat pengumuman.',
      );
    }
    if (p.judul.trim().isEmpty) {
      throw const ClassMateException('Judul pengumuman wajib diisi.');
    }
    if (p.id.isEmpty) {
      _d.pengumuman.v = [
        ..._d.pengumuman.v,
        Pengumuman(
          id: _d.idBaru('pengumuman'),
          judul: p.judul.trim(),
          isi: p.isi.trim(),
          penting: p.penting,
          namaPembuat: _p.nama,
          dibuatPada: DateTime.now(),
        ),
      ];
    } else {
      _d.pengumuman.v = [
        for (final x in _d.pengumuman.v)
          x.id == p.id
              ? x.salin(
                  judul: p.judul.trim(),
                  isi: p.isi.trim(),
                  penting: p.penting,
                )
              : x,
      ];
    }
  }

  @override
  Future<void> hapus(String id) async {
    if (!_p.isAdmin) {
      throw const ClassMateException(
        'Hanya admin dan dosen yang menghapus pengumuman.',
      );
    }
    _d.pengumuman.v = _d.pengumuman.v.where((p) => p.id != id).toList();
  }
}

class _DemoRekap implements RekapRepository {
  _DemoRekap(this._d, this._p);

  final _DataDemo _d;
  final Pengguna _p;

  void _cekPengelola() {
    if (!_p.isAdmin) {
      throw const ClassMateException(
        'Rekap hanya untuk admin kelas dan dosen.',
      );
    }
  }

  @override
  Future<String?> namaKelas() async => 'TEKOM A';

  @override
  Future<List<MahasiswaRekap>> daftarMahasiswa() async {
    _cekPengelola();
    var n = 1;
    String stambuk() => '25020410${(n++).toString().padLeft(2, '0')}';
    return [
      for (final a in _d.akun.v)
        if (a.peran != 'dosen')
          MahasiswaRekap(id: a.id, nama: a.nama, stambuk: stambuk()),
      for (final (i, nama) in _DataDemo.mahasiswaFiktif.indexed)
        MahasiswaRekap(id: 'fiktif-$i', nama: nama, stambuk: stambuk()),
    ];
  }

  @override
  Future<RekapAbsenMk> rekapAbsen(String mataKuliahId) async {
    final mahasiswa = await daftarMahasiswa();
    final sekarang = DateTime.now();
    final pertemuan = <PertemuanRekap>[];
    final hadir = <(String, String)>{};
    for (final r in _d.riwayatSesi(sekarang)) {
      if (r.mataKuliahId != mataKuliahId) continue;
      pertemuan.add(PertemuanRekap(sesiId: r.id, tanggal: r.mulai));
      for (final m in mahasiswa) {
        if (_DataDemo.hadirRiwayat(r, m.id)) hadir.add((r.id, m.id));
      }
    }
    for (final s in _d.sesi.v) {
      final selesai =
          s.keFirestore()['status'] == 'tutup' || !s.berakhir.isAfter(sekarang);
      if (s.mataKuliahId == mataKuliahId && selesai) {
        pertemuan.add(PertemuanRekap(sesiId: s.id, tanggal: s.mulai));
      }
    }
    for (final k in _d.kehadiran.v) {
      hadir.add((k.sesiId, k.uid));
    }
    return RekapAbsenMk(
      mataKuliahId: mataKuliahId,
      mahasiswa: mahasiswa,
      pertemuan: pertemuan,
      hadir: hadir,
    );
  }

  @override
  Future<RekapTugasMk> rekapTugas(String mataKuliahId) async {
    final mahasiswa = await daftarMahasiswa();
    final tugas = _d.tugas.v.where((t) => t.mataKuliahId == mataKuliahId);
    final terkumpul = <(String, String)>{
      for (final p in _d.pengumpulan.v) (p.tugasId, p.uid),
    };
    // Contoh: sebagian mahasiswa fiktif sudah mengumpulkan.
    for (final t in tugas) {
      for (final (i, m) in mahasiswa.indexed) {
        if (m.id.startsWith('fiktif-') && (i + t.id.length) % 3 != 0) {
          terkumpul.add((t.id, m.id));
        }
      }
    }
    return RekapTugasMk(
      mataKuliahId: mataKuliahId,
      mahasiswa: mahasiswa,
      tugas: [
        for (final t in tugas)
          TugasRekap(id: t.id, judul: t.judul, tenggat: t.tenggat),
      ],
      terkumpul: terkumpul,
    );
  }
}
