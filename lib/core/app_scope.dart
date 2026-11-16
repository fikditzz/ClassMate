import 'package:flutter/widgets.dart';

import '../data/backend.dart';
import '../models/mata_kuliah.dart';
import '../models/pengguna.dart';
import '../repositories/absensi_repository.dart';
import '../repositories/akun_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/jadwal_repository.dart';
import '../repositories/tugas_repository.dart';

/// Menyediakan pengguna yang login, repository, dan daftar mata kuliah
/// ke semua halaman di bawahnya.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.pengguna,
    required this.auth,
    required this.repo,
    required this.mataKuliah,
    required this.modeDemo,
    required this.bukaTab,
    required super.child,
  });

  final Pengguna pengguna;
  final AuthRepository auth;
  final RepositoriPengguna repo;
  final List<MataKuliah> mataKuliah;
  final bool modeDemo;

  /// Pindah tab bottom navigation (0 Beranda ... 4 Profil).
  final ValueChanged<int> bukaTab;

  AbsensiRepository get absensi => repo.absensi;
  TugasRepository get tugas => repo.tugas;
  JadwalRepository get jadwal => repo.jadwal;
  AkunRepository get akun => repo.akun;

  /// Halaman yang dibuka dengan Navigator.push berada di luar AppScope,
  /// jadi dibungkus ulang dengan data yang sama.
  Widget bungkus(Widget anak) => AppScope(
    pengguna: pengguna,
    auth: auth,
    repo: repo,
    mataKuliah: mataKuliah,
    modeDemo: modeDemo,
    bukaTab: bukaTab,
    child: anak,
  );

  MataKuliah? mataKuliahDari(String id) {
    for (final mk in mataKuliah) {
      if (mk.id == id) return mk;
    }
    return null;
  }

  String namaMataKuliah(String id) {
    for (final mk in mataKuliah) {
      if (mk.id == id) return mk.nama;
    }
    return id;
  }

  /// Untuk `build`: ikut dibangun ulang saat daftar mata kuliah berubah.
  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  /// Untuk `initState`: hanya membaca, tanpa berlangganan perubahan.
  static AppScope baca(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope old) =>
      mataKuliah != old.mataKuliah || pengguna != old.pengguna;
}
