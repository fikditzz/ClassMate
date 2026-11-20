import '../models/pengumuman.dart';

/// Pengumuman kelas. Semua anggota membaca; admin dan dosen mengelola.
abstract class PengumumanRepository {
  /// Terbaru di atas, yang penting tidak didahulukan (urut waktu saja).
  Future<List<Pengumuman>> daftar();

  /// Menambah (id kosong) atau mengubah pengumuman.
  Future<void> simpan(Pengumuman pengumuman);

  Future<void> hapus(String id);
}
