import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors.dart';
import '../../models/kas.dart';
import '../../models/konversi.dart';
import '../../models/pengguna.dart';
import '../../repositories/kas_repository.dart';
import 'pemetaan.dart';

/// Uang kas di tabel `kas_transaksi`.
///
/// RLS membatasi anggota hanya membaca baris miliknya, jadi ringkasan dan
/// riwayat kelas dibaca lewat fungsi `ringkasan_kas()` dan
/// `riwayat_kas_kelas()`. Untuk anggota, iuran orang lain digabung per
/// tanggal tanpa nama.
class SupabaseKasRepository implements KasRepository {
  SupabaseKasRepository(this._db, this._pengguna);

  final SupabaseClient _db;
  final Pengguna _pengguna;

  static String _tanggal(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  @override
  Future<RingkasanKas> ringkasan() async {
    try {
      final hasil = await _db.rpc('ringkasan_kas');
      final d = Map<String, dynamic>.from(hasil as Map);
      final nominal = (d['iuran_nominal'] as num?)?.toInt();
      final mulai = d['iuran_mulai'];
      return RingkasanKas(
        saldo: ((d['saldo'] as num?) ?? 0).round(),
        masukBulanIni: ((d['masuk_bulan_ini'] as num?) ?? 0).round(),
        keluarBulanIni: ((d['keluar_bulan_ini'] as num?) ?? 0).round(),
        aturan: nominal == null || nominal <= 0 || mulai == null
            ? null
            : AturanIuran(nominal: nominal, mulai: keDateTime(mulai)),
      );
    } catch (e) {
      throw pesanGagal(e, 'Gagal memuat ringkasan kas');
    }
  }

  @override
  Future<List<TransaksiKas>> riwayatKelas() async {
    try {
      final baris = await _db.rpc('riwayat_kas_kelas') as List;
      return [
        for (final r in baris)
          TransaksiKas.dariMap(Map<String, dynamic>.from(r as Map)),
      ];
    } catch (e) {
      throw pesanGagal(e, 'Gagal memuat riwayat kas');
    }
  }

  @override
  Future<List<TransaksiKas>> iuranSaya() async {
    try {
      final baris = await _db
          .from('kas_transaksi')
          .select('id, jenis, jumlah, tanggal, keterangan, user_id')
          .eq('user_id', keId(_pengguna.uid))
          .order('tanggal', ascending: false);
      return [
        for (final r in baris)
          if (JenisKas.dari(r['jenis']) == JenisKas.iuran)
            TransaksiKas.dariMap(r),
      ];
    } catch (e) {
      throw pesanGagal(e, 'Gagal memuat iuran');
    }
  }

  @override
  Future<void> simpan(TransaksiKas t) async {
    if (t.jumlah <= 0) {
      throw const ClassMateException('Nominal harus lebih dari 0.');
    }
    if (t.jenis == JenisKas.iuran && t.userId == null) {
      throw const ClassMateException('Pilih anggota yang membayar iuran.');
    }
    final data = {
      'jenis': t.jenis.name,
      'jumlah': t.jumlah,
      'tanggal': _tanggal(t.tanggal),
      'keterangan': t.keterangan.trim(),
      'user_id': t.jenis == JenisKas.iuran ? keId(t.userId!) : null,
    };
    try {
      if (t.id.isEmpty) {
        // kelas_id dan dibuat_oleh diisi database.
        await _db.from('kas_transaksi').insert(data);
      } else {
        await _db.from('kas_transaksi').update(data).eq('id', t.id);
      }
    } catch (e) {
      throw pesanGagal(e, 'Gagal menyimpan transaksi');
    }
  }

  @override
  Future<void> hapus(String id) async {
    try {
      await _db.from('kas_transaksi').delete().eq('id', id);
    } catch (e) {
      throw pesanGagal(e, 'Gagal menghapus transaksi');
    }
  }

  @override
  Future<List<StatusIuran>> statusIuran() async {
    try {
      final baris = await _db.rpc('status_iuran') as List;
      return [
        for (final raw in baris)
          if (Map<String, dynamic>.from(raw as Map) case final r)
            StatusIuran(
              userId: '${r['user_id']}',
              nama: (r['nama'] as String?) ?? '-',
              totalBayar: ((r['total'] as num?) ?? 0).round(),
              kaliBayar: (r['kali'] as num?)?.toInt() ?? 0,
              terakhir: r['terakhir'] == null
                  ? null
                  : keDateTime(r['terakhir']),
            ),
      ];
    } catch (e) {
      throw pesanGagal(e, 'Gagal memuat status iuran');
    }
  }

  @override
  Future<void> aturIuran(AturanIuran aturan) async {
    if (aturan.nominal <= 0) {
      throw const ClassMateException('Nominal iuran harus lebih dari 0.');
    }
    try {
      await _db.rpc(
        'atur_iuran',
        params: {
          'p_nominal': aturan.nominal,
          'p_mulai': _tanggal(aturan.mulai),
        },
      );
    } catch (e) {
      throw pesanGagal(e, 'Gagal menyimpan aturan iuran');
    }
  }
}
