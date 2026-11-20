import '../models/kas.dart';

/// Uang kas kelas.
///
/// Semua anggota boleh melihat [ringkasan] dan [riwayatKelas] (iuran orang
/// lain digabung tanpa nama), serta [iuranSaya]. Pencatatan, penghapusan,
/// [statusIuran], dan [aturIuran] khusus admin kelas.
abstract class KasRepository {
  Future<RingkasanKas> ringkasan();

  /// Terbaru di atas. Untuk admin berisi semua transaksi lengkap dengan nama.
  Future<List<TransaksiKas>> riwayatKelas();

  /// Iuran milik pengguna yang login, terbaru di atas.
  Future<List<TransaksiKas>> iuranSaya();

  // ---- Khusus admin ----

  /// Menambah (id kosong) atau mengubah transaksi.
  Future<void> simpan(TransaksiKas transaksi);

  Future<void> hapus(String id);

  /// Total iuran tiap anggota kelas, urut nama.
  Future<List<StatusIuran>> statusIuran();

  Future<void> aturIuran(AturanIuran aturan);
}
