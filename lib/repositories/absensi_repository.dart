import 'dart:math';

import '../models/kehadiran.dart';
import '../models/rekap_kehadiran.dart';
import '../models/sesi_absensi.dart';

abstract class AbsensiRepository {
  /// Sesi berstatus `buka` (bisa saja waktunya sudah habis; cek
  /// [SesiAbsensi.masihBerlaku]).
  Stream<List<SesiAbsensi>> sesiAktif();

  /// ID sesi yang sudah dihadiri pengguna yang sedang login.
  Stream<Set<String>> sesiYangSudahDihadiri();

  /// Mencatat kehadiran. Token salah, kedaluwarsa, atau absen ganda ditolak.
  Future<void> hadir(String sesiId, String token);

  /// Kehadiran pengguna yang login per mata kuliah, dari sesi yang sudah
  /// dimulai dan tidak dibatalkan.
  Future<RekapKehadiran> rekapKehadiranSaya();

  // ---- Khusus Admin ----

  /// Membuat sesi baru dan mengembalikan token acaknya.
  Future<String> buatSesi({
    required String mataKuliahId,
    required DateTime mulai,
    required DateTime berakhir,
  });

  Future<String> tokenSesi(String sesiId);

  Future<void> tutupSesi(String sesiId);

  Stream<List<Kehadiran>> rekapSesi(String sesiId);

  /// Token 6 karakter tanpa huruf/angka yang mudah tertukar (0/O, 1/I).
  static String buatToken([Random? acak]) {
    const huruf = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = acak ?? Random.secure();
    return List.generate(6, (_) => huruf[r.nextInt(huruf.length)]).join();
  }
}
