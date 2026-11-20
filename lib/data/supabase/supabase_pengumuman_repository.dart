import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors.dart';
import '../../models/pengumuman.dart';
import '../../repositories/pengumuman_repository.dart';
import 'pemetaan.dart';

/// Pengumuman di tabel `pengumuman`. Daftar dibaca lewat fungsi
/// `daftar_pengumuman()` agar nama pembuat ikut terbaca tanpa membuka tabel
/// `users` ke semua anggota.
class SupabasePengumumanRepository implements PengumumanRepository {
  SupabasePengumumanRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<List<Pengumuman>> daftar() async {
    try {
      final baris = await _db.rpc('daftar_pengumuman') as List;
      return [
        for (final r in baris)
          Pengumuman.dariMap(Map<String, dynamic>.from(r as Map)),
      ];
    } catch (e) {
      throw pesanGagal(e, 'Gagal memuat pengumuman');
    }
  }

  @override
  Future<void> simpan(Pengumuman p) async {
    if (p.judul.trim().isEmpty) {
      throw const ClassMateException('Judul pengumuman wajib diisi.');
    }
    final data = {
      'judul': p.judul.trim(),
      'isi': p.isi.trim(),
      'penting': p.penting,
    };
    try {
      if (p.id.isEmpty) {
        // kelas_id dan dibuat_oleh diisi database.
        await _db.from('pengumuman').insert(data);
      } else {
        await _db.from('pengumuman').update(data).eq('id', keId(p.id));
      }
    } catch (e) {
      throw pesanGagal(e, 'Gagal menyimpan pengumuman');
    }
  }

  @override
  Future<void> hapus(String id) async {
    try {
      await _db.from('pengumuman').delete().eq('id', keId(id));
    } catch (e) {
      throw pesanGagal(e, 'Gagal menghapus pengumuman');
    }
  }
}
