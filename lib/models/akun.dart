/// Satu akun di halaman Kelola Akun (khusus admin).
class Akun {
  const Akun({
    this.id = '',
    required this.nama,
    required this.username,
    required this.email,
    required this.peran,
    this.punyaLogin = false,
    this.loginTerakhir,
  });

  /// Pilihan peran sesuai constraint tabel `users`.
  static const daftarPeran = ['mahasiswa', 'dosen', 'admin'];

  static String labelUntuk(String peran) => switch (peran) {
    'admin' => 'Admin Kelas',
    'dosen' => 'Dosen',
    _ => 'Anggota',
  };

  /// Kosong untuk akun yang belum disimpan.
  final String id;
  final String nama;
  final String username;
  final String email;
  final String peran;

  /// Sudah punya akun login (email + password atau Google).
  final bool punyaLogin;
  final DateTime? loginTerakhir;

  String get labelPeran => labelUntuk(peran);

  Akun salin({String? nama, String? username, String? email, String? peran}) =>
      Akun(
        id: id,
        nama: nama ?? this.nama,
        username: username ?? this.username,
        email: email ?? this.email,
        peran: peran ?? this.peran,
        punyaLogin: punyaLogin,
        loginTerakhir: loginTerakhir,
      );
}
