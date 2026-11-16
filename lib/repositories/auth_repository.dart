import '../models/pengguna.dart';

abstract class AuthRepository {
  /// `null` berarti belum masuk atau akses ditolak.
  Stream<Pengguna?> get perubahanPengguna;

  /// Masuk dengan akun Google. Melempar [AksesDitolakException] bila email
  /// tidak terdaftar, atau ClassMateException untuk kegagalan lain.
  Future<Pengguna> masuk();

  Future<void> keluar();

  /// Mengganti password akun yang sedang login. [lama] diperiksa dulu.
  Future<void> gantiPassword(String lama, String baru);
}
