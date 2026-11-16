/// Kesalahan yang pesannya aman ditampilkan langsung ke pengguna.
class ClassMateException implements Exception {
  const ClassMateException(this.pesan);

  final String pesan;

  @override
  String toString() => pesan;
}

/// Akun Google berhasil masuk, tetapi emailnya tidak terdaftar di koleksi `users`.
class AksesDitolakException extends ClassMateException {
  const AksesDitolakException([
    super.pesan =
        'Akun ini tidak memiliki akses ke ClassMate. Hubungi admin kelas.',
  ]);
}

/// Dilempar oleh `firebase_options.dart` sementara sebelum `flutterfire configure`
/// dijalankan. Aplikasi lalu berjalan dalam mode demo.
class FirebaseBelumDikonfigurasi implements Exception {
  const FirebaseBelumDikonfigurasi();

  @override
  String toString() =>
      'Firebase belum dikonfigurasi. Jalankan `flutterfire configure`.';
}
