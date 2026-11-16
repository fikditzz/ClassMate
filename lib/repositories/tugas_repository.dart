import '../models/pengumpulan.dart';
import '../models/tugas.dart';
import 'penyimpanan_berkas.dart';

abstract class TugasRepository {
  /// Semua tugas, diurutkan dari tenggat terdekat.
  Stream<List<Tugas>> daftarTugas();

  /// Pengumpulan milik pengguna yang login, dengan kunci ID tugas.
  Stream<Map<String, Pengumpulan>> pengumpulanSaya();

  /// Mencatat metadata berkas yang sudah diunggah ke Drive. Ditolak bila
  /// tenggat sudah lewat.
  Future<void> catatPengumpulan(Tugas tugas, BerkasTerunggah berkas);

  // ---- Khusus Admin ----

  Future<void> buatTugas(Tugas tugas);

  /// Mengubah judul, mata kuliah, instruksi, atau tenggat.
  Future<void> ubahTugas(Tugas tugas);

  /// Menghapus tugas beserta semua pengumpulannya.
  Future<void> hapusTugas(String id);

  Stream<List<Pengumpulan>> pengumpulanTugas(String tugasId);
}
