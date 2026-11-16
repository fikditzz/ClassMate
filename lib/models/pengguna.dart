import 'package:flutter/material.dart';

/// Menu pintasan di dashboard. [tab] adalah indeks tab bottom navigation
/// yang dibuka ketika menu dipilih.
enum MenuItem {
  absen('Absen', Icons.how_to_reg_outlined, 1),
  tugasSaya('Tugas Saya', Icons.assignment_outlined, 2),
  buatSesi('Buat Sesi', Icons.key_outlined, 1),
  buatTugas('Buat Tugas', Icons.post_add, 2),
  rekap('Rekap', Icons.fact_check_outlined, 1),
  jadwal('Jadwal', Icons.calendar_month_outlined, 3);

  const MenuItem(this.label, this.ikon, this.tab);

  final String label;
  final IconData ikon;
  final int tab;
}

/// Pengguna terdaftar (dokumen `users/{email}`).
abstract class Pengguna {
  Pengguna({
    required this.uid,
    required String email,
    required this.nama,
    required this.username,
    this.kelasId,
  }) : email = email.toLowerCase();

  final String uid;
  final String email;
  final String nama;
  final String username;
  final String? kelasId;

  String get peran;
  String get labelPeran;

  /// Admin kelas dan dosen: mengelola mata kuliah, jadwal, sesi, dan tugas.
  bool get isAdmin => false;

  /// Hanya admin kelas yang mengelola akun anggota.
  bool get bolehKelolaAkun => peran == 'admin';

  /// Diisi berbeda oleh tiap subclass, sehingga dashboard tidak perlu
  /// memeriksa peran.
  List<MenuItem> get menuUtama;

  /// Memilih subclass berdasarkan field `peran`. Peran selain `admin` dan
  /// `dosen` (misalnya `mahasiswa` atau `anggota`) menjadi [Anggota].
  factory Pengguna.dariData({
    required String uid,
    required String email,
    required Map<String, dynamic> data,
  }) {
    final nama = (data['nama'] as String?) ?? email;
    final username = (data['username'] as String?) ?? email.split('@').first;
    final kelasId = data['kelas_id'] as String?;
    return switch (data['peran']) {
      'admin' => Admin(
        uid: uid,
        email: email,
        nama: nama,
        username: username,
        kelasId: kelasId,
      ),
      'dosen' => Dosen(
        uid: uid,
        email: email,
        nama: nama,
        username: username,
        kelasId: kelasId,
      ),
      _ => Anggota(
        uid: uid,
        email: email,
        nama: nama,
        username: username,
        kelasId: kelasId,
      ),
    };
  }
}

class Admin extends Pengguna {
  Admin({
    required super.uid,
    required super.email,
    required super.nama,
    required super.username,
    super.kelasId,
  });

  @override
  String get peran => 'admin';

  @override
  String get labelPeran => 'Admin Kelas';

  @override
  bool get isAdmin => true;

  @override
  List<MenuItem> get menuUtama => const [
    MenuItem.buatSesi,
    MenuItem.buatTugas,
    MenuItem.rekap,
    MenuItem.jadwal,
  ];
}

/// Dosen punya hak yang sama dengan admin kelas: membuat sesi absen, tugas,
/// dan mengubah jadwal.
class Dosen extends Admin {
  Dosen({
    required super.uid,
    required super.email,
    required super.nama,
    required super.username,
    super.kelasId,
  });

  @override
  String get peran => 'dosen';

  @override
  String get labelPeran => 'Dosen';
}

class Anggota extends Pengguna {
  Anggota({
    required super.uid,
    required super.email,
    required super.nama,
    required super.username,
    super.kelasId,
  });

  @override
  String get peran => 'anggota';

  @override
  String get labelPeran => 'Anggota';

  @override
  List<MenuItem> get menuUtama => const [
    MenuItem.absen,
    MenuItem.tugasSaya,
    MenuItem.jadwal,
  ];
}
