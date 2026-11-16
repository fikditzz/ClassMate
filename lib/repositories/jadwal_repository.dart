import '../models/jadwal.dart';
import '../models/mata_kuliah.dart';
import '../models/perubahan_jadwal.dart';

abstract class JadwalRepository {
  /// Semua jadwal, terurut per hari lalu jam mulai.
  Stream<List<Jadwal>> semuaJadwal();

  Stream<List<MataKuliah>> mataKuliah();

  /// Libur, pindah, dan kuliah tambahan per pertemuan.
  Stream<List<PerubahanJadwal>> perubahanJadwal();

  /// Jadwal tersimpan yang bentrok dengan [jadwal] (memakai
  /// [Jadwal.bentrokDengan]). Dipanggil sebelum [simpan].
  Future<List<Jadwal>> cariBentrok(Jadwal jadwal);

  // ---- Khusus admin dan dosen ----

  /// Menambah (id kosong) atau mengubah jadwal tetap mingguan.
  Future<void> simpan(Jadwal jadwal);

  Future<void> hapus(String id);

  /// Menambah (id kosong) atau mengubah mata kuliah.
  Future<void> simpanMataKuliah(MataKuliah mataKuliah);

  /// Menghapus mata kuliah beserta jadwal, sesi, dan tugasnya.
  Future<void> hapusMataKuliah(String id);

  /// Menambah (id kosong) atau mengubah perubahan satu pertemuan.
  Future<void> simpanPerubahan(PerubahanJadwal perubahan);

  /// Membatalkan perubahan; pertemuan kembali sesuai jadwal tetap.
  Future<void> hapusPerubahan(String id);
}
