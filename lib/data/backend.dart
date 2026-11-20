import '../models/pengguna.dart';
import '../repositories/absensi_repository.dart';
import '../repositories/akun_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/jadwal_repository.dart';
import '../repositories/kas_repository.dart';
import '../repositories/pengumuman_repository.dart';
import '../repositories/tugas_repository.dart';

/// Repository yang bergantung pada pengguna yang sedang login.
class RepositoriPengguna {
  const RepositoriPengguna({
    required this.absensi,
    required this.tugas,
    required this.jadwal,
    required this.akun,
    required this.kas,
    required this.pengumuman,
  });

  final AbsensiRepository absensi;
  final TugasRepository tugas;
  final JadwalRepository jadwal;

  /// Hanya dipakai admin kelas.
  final AkunRepository akun;

  final KasRepository kas;
  final PengumumanRepository pengumuman;
}

/// Titik masuk ke layanan data. Halaman tidak tahu apakah di baliknya
/// Firebase atau data demo.
abstract class BackendClassMate {
  AuthRepository get auth;

  RepositoriPengguna buatRepositori(Pengguna pengguna);

  bool get modeDemo;
}
