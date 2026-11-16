import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors.dart';
import '../../models/pengguna.dart';
import '../../models/pengumpulan.dart';
import '../../models/tugas.dart';
import '../../repositories/penyimpanan_berkas.dart';
import '../../repositories/tugas_repository.dart';
import 'pemetaan.dart';

class SupabaseTugasRepository implements TugasRepository {
  SupabaseTugasRepository(this._db, this._pengguna, this._email);

  final SupabaseClient _db;
  final Pengguna _pengguna;
  final PencariEmail _email;

  @override
  Stream<List<Tugas>> daftarTugas() => _db
      .from('tugas')
      .stream(primaryKey: ['id'])
      .order('tenggat', ascending: true)
      .map(
        (baris) =>
            baris.map(tugasDari).toList()
              ..sort((a, b) => a.tenggat.compareTo(b.tenggat)),
      );

  @override
  Stream<Map<String, Pengumpulan>> pengumpulanSaya() => _db
      .from('pengumpulan')
      .stream(primaryKey: ['id'])
      .eq('user_id', keId(_pengguna.uid))
      .map(
        (baris) => {
          for (final r in baris)
            '${r['tugas_id']}': pengumpulanDari(r, _pengguna.email),
        },
      );

  @override
  Future<void> catatPengumpulan(Tugas tugas, BerkasTerunggah berkas) async {
    if (tugas.sudahLewatTenggat()) {
      throw const ClassMateException('Tenggat tugas ini sudah lewat.');
    }
    try {
      // waktu_upload diisi trigger di server; RLS menolak setelah tenggat.
      await _db.from('pengumpulan').upsert({
        'tugas_id': keId(tugas.id),
        'user_id': keId(_pengguna.uid),
        'drive_file_id': berkas.fileId,
        'drive_url': berkas.url,
        'nama_file': berkas.nama,
        'ukuran': berkas.ukuran,
      }, onConflict: 'tugas_id,user_id');
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const ClassMateException(
          'Pengumpulan ditolak: tenggat sudah lewat.',
        );
      }
      throw pesanGagal(e, 'Gagal menyimpan pengumpulan');
    } catch (e) {
      throw pesanGagal(e, 'Gagal menyimpan pengumpulan');
    }
  }

  @override
  Future<void> buatTugas(Tugas tugas) async {
    try {
      // dibuat_oleh diisi otomatis oleh database dari akun yang login.
      await _db.from('tugas').insert({
        'mata_kuliah_id': keId(tugas.mataKuliahId),
        'judul': tugas.judul,
        'deskripsi': tugas.deskripsi.isEmpty ? null : tugas.deskripsi,
        'tenggat': tugas.tenggat.toUtc().toIso8601String(),
      });
    } catch (e) {
      throw pesanGagal(e, 'Gagal membuat tugas');
    }
  }

  @override
  Future<void> ubahTugas(Tugas tugas) async {
    try {
      await _db
          .from('tugas')
          .update({
            'mata_kuliah_id': keId(tugas.mataKuliahId),
            'judul': tugas.judul,
            'deskripsi': tugas.deskripsi.isEmpty ? null : tugas.deskripsi,
            'tenggat': tugas.tenggat.toUtc().toIso8601String(),
          })
          .eq('id', keId(tugas.id));
    } catch (e) {
      throw pesanGagal(e, 'Gagal mengubah tugas');
    }
  }

  @override
  Future<void> hapusTugas(String id) async {
    try {
      await _db.from('tugas').delete().eq('id', keId(id));
    } catch (e) {
      throw pesanGagal(e, 'Gagal menghapus tugas');
    }
  }

  @override
  Stream<List<Pengumpulan>> pengumpulanTugas(String tugasId) => _db
      .from('pengumpulan')
      .stream(primaryKey: ['id'])
      .eq('tugas_id', keId(tugasId))
      .asyncMap((baris) async {
        final email = await _email.untuk(baris.map((r) => '${r['user_id']}'));
        return [
          for (final r in baris) pengumpulanDari(r, email('${r['user_id']}')),
        ];
      });
}
