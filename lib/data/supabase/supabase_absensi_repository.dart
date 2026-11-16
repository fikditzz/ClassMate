import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors.dart';
import '../../models/kehadiran.dart';
import '../../models/pengguna.dart';
import '../../models/sesi_absensi.dart';
import '../../repositories/absensi_repository.dart';
import 'pemetaan.dart';

class SupabaseAbsensiRepository implements AbsensiRepository {
  SupabaseAbsensiRepository(this._db, this._pengguna, this._email);

  final SupabaseClient _db;
  final Pengguna _pengguna;
  final PencariEmail _email;

  @override
  Stream<List<SesiAbsensi>> sesiAktif() {
    // Sesi selalu dalam satu hari, jadi cukup ambil sejak kemarin (WITA).
    // Status disaring di sini, bukan lewat filter stream, agar sesi yang
    // ditutup ikut hilang dari daftar.
    final kemarin = keWita(DateTime.now().subtract(const Duration(days: 1)))
        .tanggal;
    return _db
        .from('sesi_absensi')
        .stream(primaryKey: ['id'])
        .gte('tanggal', kemarin)
        .map(
          (baris) => [
            for (final r in baris)
              if (r['status'] == 'aktif') sesiDari(r),
          ]..sort((a, b) => a.berakhir.compareTo(b.berakhir)),
        );
  }

  @override
  Stream<Set<String>> sesiYangSudahDihadiri() => _db
      .from('kehadiran')
      .stream(primaryKey: ['id'])
      .eq('user_id', keId(_pengguna.uid))
      .map((baris) => {for (final r in baris) '${r['sesi_id']}'});

  @override
  Future<void> hadir(String sesiId, String token) async {
    try {
      // Token, status, dan jam sesi diperiksa fungsi absen() di server.
      await _db
          .rpc(
            'absen',
            params: {
              'p_sesi_id': keId(sesiId),
              'p_token': token.trim().toUpperCase(),
            },
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const ClassMateException(
        'Koneksi lambat. Periksa internet lalu coba lagi.',
      );
    } on PostgrestException catch (e) {
      throw switch (e.message) {
        'sudah_absen' => const ClassMateException(
          'Kamu sudah absen di sesi ini.',
        ),
        'token_salah_atau_sesi_berakhir' => const ClassMateException(
          'Token salah atau sesi sudah berakhir.',
        ),
        'tidak_terdaftar' => const AksesDitolakException(),
        _ => ClassMateException('Gagal absen: ${e.message}'),
      };
    } catch (e) {
      throw pesanGagal(e, 'Gagal absen');
    }
  }

  @override
  Future<String> buatSesi({
    required String mataKuliahId,
    required DateTime mulai,
    required DateTime berakhir,
  }) async {
    final awal = keWita(mulai);
    final akhir = keWita(berakhir);
    if (awal.tanggal != akhir.tanggal) {
      throw const ClassMateException(
        'Sesi harus berakhir di hari yang sama (WITA).',
      );
    }
    // Token unik di seluruh sesi; bila kebetulan sama, buat token baru.
    for (var coba = 0; ; coba++) {
      final token = AbsensiRepository.buatToken();
      try {
        await _db.rpc(
          'buat_sesi',
          params: {
            'p_mata_kuliah_id': keId(mataKuliahId),
            'p_tanggal': awal.tanggal,
            'p_jam_mulai': awal.jam,
            'p_jam_selesai': akhir.jam,
            'p_token': token,
          },
        );
        return token;
      } on PostgrestException catch (e) {
        if (e.code == '23505' && coba < 3) continue;
        throw pesanGagal(e, 'Gagal membuat sesi');
      } catch (e) {
        throw pesanGagal(e, 'Gagal membuat sesi');
      }
    }
  }

  @override
  Future<String> tokenSesi(String sesiId) async {
    final r = await _db
        .from('sesi_token')
        .select('token')
        .eq('sesi_id', keId(sesiId))
        .maybeSingle();
    return (r?['token'] as String?) ?? '-';
  }

  @override
  Future<void> tutupSesi(String sesiId) async {
    try {
      await _db
          .from('sesi_absensi')
          .update({'status': 'ditutup'})
          .eq('id', keId(sesiId));
    } catch (e) {
      throw pesanGagal(e, 'Gagal menutup sesi');
    }
  }

  @override
  Stream<List<Kehadiran>> rekapSesi(String sesiId) => _db
      .from('kehadiran')
      .stream(primaryKey: ['id'])
      .eq('sesi_id', keId(sesiId))
      .asyncMap((baris) async {
        final email = await _email.untuk(baris.map((r) => '${r['user_id']}'));
        return [
          for (final r in baris) kehadiranDari(r, email('${r['user_id']}')),
        ]..sort((a, b) => a.waktuAbsen.compareTo(b.waktuAbsen));
      });
}
