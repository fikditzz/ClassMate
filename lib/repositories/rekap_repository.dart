import '../models/rekap.dart';

/// Data rekap untuk dokumen ekspor. Khusus admin kelas dan dosen.
abstract class RekapRepository {
  /// Nama kelas pengguna, misalnya "TEKOM A". null bila tidak diketahui.
  Future<String?> namaKelas();

  /// Mahasiswa kelas (termasuk admin kelas, tanpa dosen).
  Future<List<MahasiswaRekap>> daftarMahasiswa();

  /// Daftar hadir satu mata kuliah dari sesi yang sudah selesai atau ditutup
  /// (sesi yang masih berjalan belum dihitung).
  Future<RekapAbsenMk> rekapAbsen(String mataKuliahId);

  /// Pengumpulan semua tugas satu mata kuliah.
  Future<RekapTugasMk> rekapTugas(String mataKuliahId);
}
