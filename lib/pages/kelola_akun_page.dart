import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/errors.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/akun.dart';
import '../repositories/akun_repository.dart';
import '../widgets/animasi.dart';
import '../widgets/kolom_password.dart';
import '../widgets/umum.dart';

void bukaKelolaAkun(BuildContext context) {
  final scope = AppScope.baca(context);
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => scope.bungkus(const KelolaAkunPage()),
    ),
  );
}

/// Khusus admin kelas: menambah, mengubah, mengatur password, dan menghapus
/// akun anggota, dosen, maupun admin lain.
class KelolaAkunPage extends StatefulWidget {
  const KelolaAkunPage({super.key});

  @override
  State<KelolaAkunPage> createState() => _KelolaAkunPageState();
}

class _KelolaAkunPageState extends State<KelolaAkunPage> {
  late Future<List<Akun>> _akun;
  final _cari = TextEditingController();

  @override
  void initState() {
    super.initState();
    _akun = AppScope.baca(context).akun.daftarAkun();
    _cari.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  Future<void> _muatUlang() async {
    final baru = AppScope.baca(context).akun.daftarAkun();
    setState(() => _akun = baru);
    await baru.catchError((_) => <Akun>[]);
  }

  Future<void> _bukaForm(Akun? awal) async {
    final scope = AppScope.baca(context);
    final berubah = await bukaLembar<bool>(
      context,
      judul: awal == null ? 'Tambah Akun' : 'Ubah Akun',
      subjudul: awal == null
          ? 'Akun langsung bisa login dengan email dan password ini.'
          : awal.email,
      isi: (_) => _FormAkun(scope: scope, awal: awal),
    );
    if (berubah == true && mounted) await _muatUlang();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final saya = AppScope.of(context).pengguna;
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Akun')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _bukaForm(null),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Tambah Akun'),
      ),
      body: RefreshIndicator(
        onRefresh: _muatUlang,
        child: FutureBuilder<List<Akun>>(
          future: _akun,
          builder: (context, snap) {
            if (snap.hasError) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  KotakInfo(
                    jenis: JenisStatus.bahaya,
                    ikon: Icons.error_outline,
                    teks: snap.error is ClassMateException
                        ? (snap.error! as ClassMateException).pesan
                        : 'Gagal memuat akun: ${snap.error}',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _muatUlang,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba lagi'),
                  ),
                ],
              );
            }
            if (!snap.hasData) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  KartuKerangka(),
                  SizedBox(height: 12),
                  KartuKerangka(),
                ],
              );
            }
            final semua = snap.data!;
            final kata = _cari.text.trim().toLowerCase();
            final daftar = kata.isEmpty
                ? semua
                : semua
                      .where(
                        (a) =>
                            a.nama.toLowerCase().contains(kata) ||
                            a.email.contains(kata) ||
                            a.username.contains(kata),
                      )
                      .toList();
            int jumlah(String peran) =>
                semua.where((a) => a.peran == peran).length;
            final belumLogin = semua.where((a) => !a.punyaLogin).length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChipStatus('${semua.length} akun', jenis: JenisStatus.info),
                    ChipStatus(
                      'Admin ${jumlah('admin')}',
                      jenis: JenisStatus.netral,
                    ),
                    ChipStatus(
                      'Dosen ${jumlah('dosen')}',
                      jenis: JenisStatus.netral,
                    ),
                    ChipStatus(
                      'Anggota ${jumlah('mahasiswa')}',
                      jenis: JenisStatus.netral,
                    ),
                    if (belumLogin > 0)
                      ChipStatus(
                        '$belumLogin belum punya password',
                        jenis: JenisStatus.peringatan,
                        ikon: Icons.lock_open_outlined,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cari,
                  decoration: const InputDecoration(
                    hintText: 'Cari nama, email, atau username…',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 16),
                if (daftar.isEmpty)
                  const Kartu(
                    child: KeadaanKosong(
                      ikon: Icons.person_search_outlined,
                      judul: 'Akun tidak ditemukan',
                      ringkas: true,
                    ),
                  ),
                for (final (i, a) in daftar.indexed) ...[
                  Muncul(
                    urutan: i,
                    child: Kartu(
                      onTap: () => _bukaForm(a),
                      child: Row(
                        children: [
                          AvatarInisial(a.nama, ukuran: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.id == saya.uid
                                      ? '${a.nama} (kamu)'
                                      : a.nama,
                                  style: t.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '@${a.username} • ${a.email}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.bodySmall,
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    ChipStatus(
                                      a.labelPeran,
                                      jenis: a.peran == 'mahasiswa'
                                          ? JenisStatus.netral
                                          : JenisStatus.info,
                                    ),
                                    if (!a.punyaLogin)
                                      const ChipStatus(
                                        'Belum punya password',
                                        jenis: JenisStatus.peringatan,
                                      )
                                    else if (a.loginTerakhir != null)
                                      ChipStatus(
                                        'Login ${formatTenggat(a.loginTerakhir!)}',
                                        jenis: JenisStatus.netral,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Warna.teksSekunder,
                          ),
                        ],
                      ),
                    ),
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

class _FormAkun extends StatefulWidget {
  const _FormAkun({required this.scope, this.awal});

  final AppScope scope;
  final Akun? awal;

  @override
  State<_FormAkun> createState() => _FormAkunState();
}

class _FormAkunState extends State<_FormAkun> {
  final _kunci = GlobalKey<FormState>();
  late final _nama = TextEditingController(text: widget.awal?.nama ?? '');
  late final _username = TextEditingController(
    text: widget.awal?.username ?? '',
  );
  late final _email = TextEditingController(text: widget.awal?.email ?? '');
  final _password = TextEditingController();
  final _ulang = TextEditingController();
  late String _peran = widget.awal?.peran ?? 'mahasiswa';
  bool _memproses = false;
  String? _galat;

  bool get _baru => widget.awal == null;
  bool get _diriSendiri => widget.awal?.id == widget.scope.pengguna.uid;
  AkunRepository get _repo => widget.scope.akun;

  @override
  void dispose() {
    for (final c in [_nama, _username, _email, _password, _ulang]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _jalankan(Future<void> Function() aksi, String berhasil) async {
    setState(() {
      _memproses = true;
      _galat = null;
    });
    try {
      await aksi();
      if (mounted) {
        Navigator.pop(context, true);
        tampilkanPesan(context, berhasil);
      }
    } on ClassMateException catch (e) {
      if (mounted) setState(() => _galat = e.pesan);
    } catch (e) {
      if (mounted) setState(() => _galat = '$e');
    } finally {
      if (mounted) setState(() => _memproses = false);
    }
  }

  Akun get _isian => Akun(
    id: widget.awal?.id ?? '',
    nama: _nama.text.trim(),
    username: _username.text.trim().toLowerCase(),
    email: _email.text.trim().toLowerCase(),
    peran: _peran,
  );

  Future<void> _simpan() async {
    if (!_kunci.currentState!.validate()) return;
    await _jalankan(
      () => _baru
          ? _repo.buatAkun(_isian, _password.text)
          : _repo.ubahAkun(_isian),
      _baru ? 'Akun ${_isian.nama} ditambahkan.' : 'Akun disimpan.',
    );
  }

  Future<void> _aturPassword() async {
    final awal = widget.awal!;
    final pw = await bukaLembar<String>(
      context,
      judul: 'Atur Password Baru',
      subjudul:
          'Untuk ${awal.nama}. Password lama tidak diperlukan. Sampaikan '
          'password baru langsung ke pemilik akun.',
      isi: (_) => const _FormPasswordBaru(),
    );
    if (pw == null || !mounted) return;
    await _jalankan(
      () => _repo.aturPassword(awal.id, pw),
      'Password ${awal.nama} sudah diganti.',
    );
  }

  Future<void> _hapus() async {
    final awal = widget.awal!;
    final ya = await konfirmasi(
      context,
      ikon: Icons.person_remove_outlined,
      judul: 'Hapus akun ${awal.nama}?',
      pesan:
          'Akun tidak bisa login lagi. Riwayat kehadiran dan pengumpulan '
          'tugasnya ikut terhapus. Tindakan ini tidak bisa dibatalkan.',
      tombolYa: 'Hapus Akun',
      bahaya: true,
    );
    if (!ya || !mounted) return;
    await _jalankan(
      () => _repo.hapusAkun(awal.id),
      'Akun ${awal.nama} dihapus.',
    );
  }

  String? _wajib(String? v, String nama) =>
      (v == null || v.trim().isEmpty) ? '$nama wajib diisi' : null;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Form(
      key: _kunci,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nama,
            enabled: !_memproses,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama lengkap',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (v) => _wajib(v, 'Nama'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _username,
            enabled: !_memproses,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.alternate_email),
            ),
            validator: (v) {
              final w = _wajib(v, 'Username');
              if (w != null) return w;
              return RegExp(r'^[a-zA-Z0-9._]{3,30}$').hasMatch(v!.trim())
                  ? null
                  : '3–30 huruf, angka, titik, atau garis bawah';
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            enabled: !_memproses,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: (v) {
              final w = _wajib(v, 'Email');
              if (w != null) return w;
              return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$')
                      .hasMatch(v!.trim())
                  ? null
                  : 'Format email tidak valid';
            },
          ),
          const SizedBox(height: 16),
          Text('Peran', style: t.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              for (final p in Akun.daftarPeran)
                ButtonSegment(value: p, label: Text(Akun.labelUntuk(p))),
            ],
            selected: {_peran},
            onSelectionChanged: _memproses || _diriSendiri
                ? null
                : (s) => setState(() => _peran = s.first),
          ),
          const SizedBox(height: 6),
          Text(switch (_peran) {
            'admin' =>
              'Mengelola semua data kelas, termasuk akun dan password.',
            'dosen' => 'Mengelola mata kuliah, jadwal, sesi absen, dan tugas.',
            _ => 'Absen, mengumpulkan tugas, dan melihat jadwal.',
          }, style: t.bodySmall),
          if (_diriSendiri) ...[
            const SizedBox(height: 4),
            Text(
              'Peranmu sendiri tidak bisa diubah agar kelas tidak kehilangan admin.',
              style: t.bodySmall?.copyWith(color: Warna.peringatanTeks),
            ),
          ],
          if (_baru) ...[
            const SizedBox(height: 16),
            KolomPassword(
              controller: _password,
              label: 'Password awal',
              enabled: !_memproses,
            ),
            const SizedBox(height: 12),
            KolomPassword(
              controller: _ulang,
              label: 'Ulangi password',
              cocokDengan: _password,
              enabled: !_memproses,
              textInputAction: TextInputAction.done,
            ),
          ],
          if (_galat != null) ...[
            const SizedBox(height: 16),
            KotakInfo(
              jenis: JenisStatus.bahaya,
              ikon: Icons.error_outline,
              teks: _galat!,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _memproses ? null : _simpan,
            child: Text(
              _memproses
                  ? 'Menyimpan…'
                  : _baru
                  ? 'Tambah Akun'
                  : 'Simpan Perubahan',
            ),
          ),
          if (!_baru) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _memproses ? null : _aturPassword,
              icon: const Icon(Icons.key_outlined),
              label: Text(
                widget.awal!.punyaLogin
                    ? 'Atur Password Baru'
                    : 'Buat Password Login',
              ),
            ),
            if (!_diriSendiri) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _memproses ? null : _hapus,
                style: TextButton.styleFrom(foregroundColor: Warna.bahaya),
                icon: const Icon(Icons.person_remove_outlined),
                label: const Text('Hapus Akun'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Mengembalikan password baru yang sudah diulang dengan benar.
class _FormPasswordBaru extends StatefulWidget {
  const _FormPasswordBaru();

  @override
  State<_FormPasswordBaru> createState() => _FormPasswordBaruState();
}

class _FormPasswordBaruState extends State<_FormPasswordBaru> {
  final _kunci = GlobalKey<FormState>();
  final _baru = TextEditingController();
  final _ulang = TextEditingController();

  @override
  void dispose() {
    _baru.dispose();
    _ulang.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _kunci,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KolomPassword(controller: _baru, label: 'Password baru'),
          const SizedBox(height: 12),
          KolomPassword(
            controller: _ulang,
            label: 'Ulangi password baru',
            cocokDengan: _baru,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              if (_kunci.currentState!.validate()) {
                Navigator.pop(context, _baru.text);
              }
            },
            child: const Text('Simpan Password'),
          ),
        ],
      ),
    );
  }
}
