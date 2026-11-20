import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/konversi.dart';
import '../../models/rekap.dart';
import '../../repositories/rekap_repository.dart';
import 'pemetaan.dart';

/// Rekap lewat fungsi `daftar_mahasiswa()` dan `rekap_absen()` (khusus
/// admin dan dosen), ditambah tabel tugas dan pengumpulan.
class SupabaseRekapRepository implements RekapRepository {
  SupabaseRekapRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<String?> namaKelas() async {
    try {
      final d = await _db.rpc('pengguna_saya');
      return d is Map ? d['nama_kelas'] as String? : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<MahasiswaRekap>> daftarMahasiswa() async {
    try {
      final baris = await _db.rpc('daftar_mahasiswa') as List;
      return [
        for (final raw in baris)
          if (Map<String, dynamic>.from(raw as Map) case final r)
            MahasiswaRekap(
              id: '${r['id']}',
              nama: (r['nama'] as String?) ?? '-',
              stambuk: (r['username'] as String?) ?? '',
            ),
      ]..sort(MahasiswaRekap.urutkan);
    } catch (e) {
      throw pesanGagal(e, 'Gagal memuat daftar mahasiswa');
    }
  }

  @override
  Future<RekapAbsenMk> rekapAbsen(String mataKuliahId) async {
    try {
      final memuatMahasiswa = daftarMahasiswa();
      final raw = await _db.rpc(
        'rekap_absen',
        params: {'p_mata_kuliah_id': keId(mataKuliahId)},
      );
      final mahasiswa = await memuatMahasiswa;
      final d = raw is Map
          ? Map<String, dynamic>.from(raw)
          : const <String, dynamic>{};
      final sekarang = DateTime.now();
      final pertemuan = <PertemuanRekap>[
        for (final raw in (d['sesi'] as List?) ?? const [])
          if (Map<String, dynamic>.from(raw as Map) case final s)
            if (s['status'] != 'dibatalkan' &&
                (s['status'] == 'tutup' ||
                    !dariWita(
                      '${s['tanggal']}',
                      '${s['jam_selesai']}',
                    ).isAfter(sekarang)))
              PertemuanRekap(
                sesiId: '${s['id']}',
                tanggal: dariWita('${s['tanggal']}', '${s['jam_mulai']}'),
              ),
      ];
      return RekapAbsenMk(
        mataKuliahId: mataKuliahId,
        mahasiswa: mahasiswa,
        pertemuan: pertemuan,
        hadir: {
          for (final raw in (d['hadir'] as List?) ?? const [])
            if (raw is Map) ('${raw['sesi_id']}', '${raw['user_id']}'),
        },
      );
    } catch (e) {
      throw pesanGagal(e, 'Gagal memuat rekap absen');
    }
  }

  @override
  Future<RekapTugasMk> rekapTugas(String mataKuliahId) async {
    try {
      final mahasiswa = await daftarMahasiswa();
      final tugas = await _db
          .from('tugas')
          .select('id, judul, tenggat')
          .eq('mata_kuliah_id', keId(mataKuliahId));
      final ids = [for (final t in tugas) t['id']];
      final kumpul = ids.isEmpty
          ? const <Map<String, dynamic>>[]
          : await _db
                .from('pengumpulan')
                .select('tugas_id, user_id')
                .inFilter('tugas_id', ids);
      return RekapTugasMk(
        mataKuliahId: mataKuliahId,
        mahasiswa: mahasiswa,
        tugas: [
          for (final t in tugas)
            TugasRekap(
              id: '${t['id']}',
              judul: (t['judul'] as String?) ?? '(tanpa judul)',
              tenggat: keDateTime(t['tenggat']),
            ),
        ],
        terkumpul: {
          for (final k in kumpul) ('${k['tugas_id']}', '${k['user_id']}'),
        },
      );
    } catch (e) {
      throw pesanGagal(e, 'Gagal memuat rekap tugas');
    }
  }
}
