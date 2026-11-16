import 'dart:async';

import '../../core/errors.dart';
import '../../models/akun.dart';
import '../../models/jadwal.dart';
import '../../models/kehadiran.dart';
import '../../models/mata_kuliah.dart';
import '../../models/pengguna.dart';
import '../../models/pengumpulan.dart';
import '../../models/perubahan_jadwal.dart';
import '../../models/sesi_absensi.dart';
import '../../models/tugas.dart';
import '../../repositories/absensi_repository.dart';
import '../../repositories/akun_repository.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/jadwal_repository.dart';
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
  }

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
