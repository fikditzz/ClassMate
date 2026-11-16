import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors.dart';
import '../../models/akun.dart';
import '../../repositories/akun_repository.dart';
import 'pemetaan.dart';

/// Daftar akun dibaca lewat fungsi `daftar_akun()`; perubahan akun dan
/// password lewat Edge Function `kelola-akun` (butuh kunci rahasia server).
class SupabaseAkunRepository implements AkunRepository {
  SupabaseAkunRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<List<Akun>> daftarAkun() async {
    try {
      final baris = await _db.rpc('daftar_akun') as List;
      return [for (final r in baris) akunDari(Map<String, dynamic>.from(r))];
    } catch (e) {
      throw pesanGagal(e, 'Gagal memuat daftar akun');
    }
  }

  Future<void> _kirim(Map<String, dynamic> isi, String gagal) async {
    try {
      await _db.functions.invoke('kelola-akun', body: isi);
    } catch (e) {
      throw pesanGagal(e, gagal);
    }
  }

  static void _cekPassword(String pw) {
    if (pw.length < AkunRepository.panjangPassword) {
      throw const ClassMateException(
        'Password minimal ${AkunRepository.panjangPassword} karakter.',
      );
    }
  }

  Map<String, dynamic> _data(Akun a) => {
    'nama': a.nama,
    'username': a.username,
    'email': a.email,
    'peran': a.peran,
  };

  @override
  Future<void> buatAkun(Akun akun, String password) {
    _cekPassword(password);
    return _kirim({
      'aksi': 'buat',
      ..._data(akun),
      'password': password,
    }, 'Gagal menambah akun');
  }

  @override
  Future<void> ubahAkun(Akun akun) => _kirim({
    'aksi': 'ubah',
    'id': keId(akun.id),
    ..._data(akun),
  }, 'Gagal mengubah akun');

  @override
  Future<void> aturPassword(String id, String passwordBaru) {
    _cekPassword(passwordBaru);
    return _kirim({
      'aksi': 'atur_password',
      'id': keId(id),
      'password': passwordBaru,
    }, 'Gagal mengatur password');
  }

  @override
  Future<void> hapusAkun(String id) =>
      _kirim({'aksi': 'hapus', 'id': keId(id)}, 'Gagal menghapus akun');
}
