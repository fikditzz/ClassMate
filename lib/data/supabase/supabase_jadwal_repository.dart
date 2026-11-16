import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors.dart';
import '../../models/jadwal.dart';
import '../../models/mata_kuliah.dart';
import '../../models/perubahan_jadwal.dart';
import '../../repositories/jadwal_repository.dart';
import 'pemetaan.dart';

class SupabaseJadwalRepository implements JadwalRepository {
  SupabaseJadwalRepository(this._db);

  final SupabaseClient _db;

  @override
  Stream<List<Jadwal>> semuaJadwal() => _db
      .from('jadwal')
      .stream(primaryKey: ['id'])
      .map(
        (baris) =>
            baris.map(jadwalDari).toList()..sort((a, b) => a.bandingkan(b)),
      );

  @override
  Stream<List<MataKuliah>> mataKuliah() => _db
      .from('mata_kuliah')
      .stream(primaryKey: ['id'])
      .map(
        (baris) =>
            baris.map(mataKuliahDari).toList()
              ..sort((a, b) => a.nama.compareTo(b.nama)),
      );

  @override
  Stream<List<PerubahanJadwal>> perubahanJadwal() => _db
      .from('perubahan_jadwal')
      .stream(primaryKey: ['id'])
      .map((baris) => baris.map(perubahanDari).toList());

  @override
  Future<void> simpanMataKuliah(MataKuliah mataKuliah) async {
    try {
      final data = mataKuliahKeBaris(mataKuliah);
      if (mataKuliah.id.isEmpty) {
        // kelas_id diisi database dari kelas akun yang login.
        await _db.from('mata_kuliah').insert(data);
      } else {
        await _db
            .from('mata_kuliah')
            .update(data)
            .eq('id', keId(mataKuliah.id));
      }
    } on PostgrestException catch (e) {
      throw switch (e.code) {
        '23505' => const ClassMateException(
          'Mata kuliah dengan nama ini sudah ada.',
        ),
        '23502' => const ClassMateException(
          'Akunmu belum terhubung ke kelas mana pun. Hubungi admin.',
        ),
        _ => pesanGagal(e, 'Gagal menyimpan mata kuliah'),
      };
    } catch (e) {
      throw pesanGagal(e, 'Gagal menyimpan mata kuliah');
    }
  }

  @override
  Future<void> hapusMataKuliah(String id) async {
    try {
      await _db.from('mata_kuliah').delete().eq('id', keId(id));
    } catch (e) {
      throw pesanGagal(e, 'Gagal menghapus mata kuliah');
    }
  }

  @override
  Future<void> simpanPerubahan(PerubahanJadwal perubahan) async {
    try {
      final data = perubahanKeBaris(perubahan);
      if (perubahan.id.isEmpty) {
        await _db.from('perubahan_jadwal').insert(data);
      } else {
        await _db
            .from('perubahan_jadwal')
            .update(data)
            .eq('id', keId(perubahan.id));
      }
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const ClassMateException(
          'Pertemuan ini sudah punya perubahan. Batalkan dulu yang lama.',
        );
      }
      throw pesanGagal(e, 'Gagal menyimpan perubahan jadwal');
    } catch (e) {
      throw pesanGagal(e, 'Gagal menyimpan perubahan jadwal');
    }
  }

  @override
  Future<void> hapusPerubahan(String id) async {
    try {
      await _db.from('perubahan_jadwal').delete().eq('id', keId(id));
    } catch (e) {
      throw pesanGagal(e, 'Gagal membatalkan perubahan');
    }
  }

  @override
  Future<List<Jadwal>> cariBentrok(Jadwal jadwal) async {
    // Bentrok antar baris tidak bisa dicek oleh RLS, jadi dicek di sini.
    final baris = await _db
        .from('jadwal')
        .select()
        .eq('hari', namaHari(jadwal.hari));
    return baris.map(jadwalDari).where(jadwal.bentrokDengan).toList();
  }

  @override
  Future<void> simpan(Jadwal jadwal) async {
    try {
      final data = jadwalKeBaris(jadwal);
      if (jadwal.id.isEmpty) {
        await _db.from('jadwal').insert(data);
      } else {
        await _db.from('jadwal').update(data).eq('id', keId(jadwal.id));
      }
    } catch (e) {
      throw pesanGagal(e, 'Gagal menyimpan jadwal');
    }
  }

  @override
  Future<void> hapus(String id) async {
    try {
      await _db.from('jadwal').delete().eq('id', keId(id));
    } catch (e) {
      throw pesanGagal(e, 'Gagal menghapus jadwal');
    }
  }
}
