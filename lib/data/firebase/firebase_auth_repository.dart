import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/errors.dart';
import '../../models/pengguna.dart';
import '../../repositories/auth_repository.dart';
import 'tidak_didukung.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final GoogleSignIn _google = GoogleSignIn.instance;
  Future<void>? _inisialisasiGoogle;

  Future<void> _siapkanGoogle() => _inisialisasiGoogle ??= _google.initialize();

  @override
  Stream<Pengguna?> get perubahanPengguna =>
      _auth.authStateChanges().asyncMap((user) async {
        if (user == null) return null;
        try {
          return await _muatPengguna(user);
        } on AksesDitolakException {
          await keluar();
          return null;
        }
      });

  @override
  Future<Pengguna> masuk() async {
    try {
      await _siapkanGoogle();
      final akun = await _google.authenticate();
      final idToken = akun.authentication.idToken;
      if (idToken == null) {
        throw const ClassMateException('Google tidak mengembalikan token.');
      }
      final hasil = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      return await _muatPengguna(hasil.user!);
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
    } on FirebaseAuthException catch (e) {
      throw ClassMateException('Login gagal: ${e.message ?? e.code}');
    }
  }

  @override
  Future<void> keluar() async {
    await _auth.signOut();
    try {
      await _siapkanGoogle();
      await _google.signOut();
    } catch (_) {
      // Sesi Google yang gagal ditutup tidak menghalangi keluar dari Firebase.
    }
  }

  @override
  Future<void> gantiPassword(String lama, String baru) async => tidakDidukung();

  /// Mencari email di koleksi `users`. Email lain langsung ditolak.
  Future<Pengguna> _muatPengguna(User user) async {
    final email = user.email?.toLowerCase();
    if (email == null) throw const AksesDitolakException();
    try {
      final doc = await _db.collection('users').doc(email).get();
      final data = doc.data();
      if (!doc.exists || data == null) throw const AksesDitolakException();
      return Pengguna.dariData(uid: user.uid, email: email, data: data);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw const AksesDitolakException();
      throw ClassMateException(
        'Gagal memuat data akun: ${e.message ?? e.code}',
      );
    }
  }
}
