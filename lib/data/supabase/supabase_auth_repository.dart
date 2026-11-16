import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors.dart';
import '../../models/pengguna.dart';
import '../../repositories/akun_repository.dart';
import '../../repositories/auth_repository.dart';
import '../../supabase_options.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._db);

  final SupabaseClient _db;
  final GoogleSignIn _google = GoogleSignIn.instance;
  Future<void>? _inisialisasiGoogle;

  GoTrueClient get _auth => _db.auth;

  bool get _apple =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> _siapkanGoogle() => _inisialisasiGoogle ??= _google.initialize(
    clientId: _apple && SupabaseOptions.googleIosClientId.isNotEmpty
        ? SupabaseOptions.googleIosClientId
        : null,
    serverClientId: SupabaseOptions.googleWebClientId,
  );

  @override
  Stream<Pengguna?> get perubahanPengguna => _auth.onAuthStateChange
      // Token diperbarui tiap jam; data akun tidak perlu dimuat ulang.
      .where((s) => s.event != AuthChangeEvent.tokenRefreshed)
      .asyncMap((s) async {
        final user = s.session?.user;
        if (user == null) return null;
        try {
          return await _muatPengguna(user);
        } on AksesDitolakException {
          await keluar();
          return null;
        }
      });

  /// Tombol Google hanya ditampilkan setelah Web Client ID diisi.
  bool get googleTersedia => SupabaseOptions.googleWebClientId.isNotEmpty;

  /// Masuk dengan email dan password akun Supabase Auth. Akunnya dibuat admin
  /// di dashboard (Authentication → Users), dan emailnya harus ada di `users`.
  Future<Pengguna> masukDenganPassword(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      throw const ClassMateException('Isi email dan password.');
    }
    try {
      final hasil = await _auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final user = hasil.user;
      if (user == null) throw const ClassMateException('Login gagal.');
      return await _muatPengguna(user);
    } on AksesDitolakException {
      await keluar();
      rethrow;
    } on AuthException catch (e) {
      throw ClassMateException(switch (e.code) {
        'invalid_credentials' => 'Email atau password salah.',
        'email_not_confirmed' =>
          'Email belum dikonfirmasi. Hubungi admin kelas.',
        'email_provider_disabled' =>
          'Login dengan email dimatikan di Supabase. Hubungi admin kelas.',
        _ => 'Login gagal: ${e.message}',
      });
    }
  }

  @override
  Future<Pengguna> masuk() async {
    if (!googleTersedia) {
      throw const ClassMateException(
        'Login Google belum disiapkan. Gunakan email dan password.',
      );
    }
    try {
      await _siapkanGoogle();
      final akun = await _google.authenticate();
      final idToken = akun.authentication.idToken;
      if (idToken == null) {
        throw const ClassMateException('Google tidak mengembalikan token.');
      }
      final hasil = await _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      final user = hasil.user;
      if (user == null) throw const ClassMateException('Login gagal.');
      return await _muatPengguna(user);
    } on AksesDitolakException {
      await keluar();
      rethrow;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const ClassMateException('Login dibatalkan.');
      }
      throw ClassMateException(
        'Login Google gagal: ${e.description ?? e.code.name}',
      );
    } on AuthException catch (e) {
      throw ClassMateException('Login gagal: ${e.message}');
    }
  }

  @override
  Future<void> gantiPassword(String lama, String baru) async {
    final email = _auth.currentUser?.email;
    if (email == null) {
      throw const ClassMateException('Silakan login ulang terlebih dahulu.');
    }
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
    try {
      // Password lama dibuktikan dengan login ulang.
      await _auth.signInWithPassword(email: email, password: lama);
    } on AuthException catch (e) {
      throw ClassMateException(
        e.code == 'invalid_credentials'
            ? 'Password lama salah.'
            : 'Gagal memeriksa password lama: ${e.message}',
      );
    }
    try {
      await _auth.updateUser(UserAttributes(password: baru));
    } on AuthException catch (e) {
      throw ClassMateException(switch (e.code) {
        'same_password' => 'Password baru harus berbeda dari password lama.',
        'weak_password' => 'Password baru terlalu lemah: ${e.message}',
        _ => 'Gagal mengganti password: ${e.message}',
      });
    }
  }

  @override
  Future<void> keluar() async {
    await _auth.signOut();
    if (!googleTersedia) return;
    try {
      await _siapkanGoogle();
      await _google.signOut();
    } catch (_) {
      // Sesi Google yang gagal ditutup tidak menghalangi keluar dari Supabase.
    }
  }

  /// Mencari akun di tabel `users` lewat fungsi `pengguna_saya()`. Email yang
  /// tidak terdaftar atau belum terverifikasi menghasilkan null dan ditolak.
  Future<Pengguna> _muatPengguna(User user) async {
    final email = user.email?.toLowerCase();
    if (email == null) throw const AksesDitolakException();
    final Object? hasil;
    try {
      hasil = await _db.rpc('pengguna_saya');
    } on PostgrestException catch (e) {
      throw ClassMateException('Gagal memuat data akun: ${e.message}');
    }
    if (hasil is! Map) throw const AksesDitolakException();
    final d = Map<String, dynamic>.from(hasil);
    final namaKelas = d['nama_kelas'] == null
        ? d['kelas_id']?.toString()
        : [d['nama_kelas'], d['angkatan']].whereType<Object>().join(' ');
    return Pengguna.dariData(
      uid: '${d['id']}',
      email: (d['email'] as String?) ?? email,
      data: {
        'nama': d['nama'],
        'username': d['username'],
        'peran': d['peran'],
        'kelas_id': namaKelas,
      },
    );
  }
}
