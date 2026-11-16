import '../models/akun.dart';

/// Pengelolaan akun oleh admin kelas: data di tabel `users` sekaligus akun
/// login (email + password).
abstract class AkunRepository {
  /// Panjang minimal password baru.
  static const panjangPassword = 8;

  Future<List<Akun>> daftarAkun();

  /// Menambah akun beserta password awalnya.
  Future<void> buatAkun(Akun akun, String password);

  /// Mengubah nama, username, email, atau peran.
  Future<void> ubahAkun(Akun akun);

  /// Mengatur password baru tanpa perlu password lama (lupa password).
  Future<void> aturPassword(String id, String passwordBaru);

  Future<void> hapusAkun(String id);
}
