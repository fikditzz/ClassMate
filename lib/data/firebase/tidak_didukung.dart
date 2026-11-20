import '../../core/errors.dart';
import '../../models/akun.dart';
import '../../models/kas.dart';
import '../../models/pengumuman.dart';
import '../../models/rekap.dart';
import '../../repositories/akun_repository.dart';
import '../../repositories/kas_repository.dart';
import '../../repositories/pengumuman_repository.dart';
import '../../repositories/rekap_repository.dart';

/// Backend Firebase lama tidak lagi dikembangkan; fitur baru hanya ada di
/// Supabase dan mode demo.
Never tidakDidukung() => throw const ClassMateException(
  'Fitur ini hanya tersedia dengan backend Supabase.',
);

class AkunTidakDidukung implements AkunRepository {
  const AkunTidakDidukung();

  @override
  Future<List<Akun>> daftarAkun() async => tidakDidukung();

  @override
  Future<void> buatAkun(Akun akun, String password) async => tidakDidukung();

  @override
  Future<void> ubahAkun(Akun akun) async => tidakDidukung();

  @override
  Future<void> aturPassword(String id, String passwordBaru) async =>
      tidakDidukung();

  @override
  Future<void> hapusAkun(String id) async => tidakDidukung();
}

class KasTidakDidukung implements KasRepository {
  const KasTidakDidukung();

  @override
  Future<RingkasanKas> ringkasan() async => tidakDidukung();

  @override
  Future<List<TransaksiKas>> riwayatKelas() async => tidakDidukung();

  @override
  Future<List<TransaksiKas>> iuranSaya() async => tidakDidukung();

  @override
  Future<void> simpan(TransaksiKas transaksi) async => tidakDidukung();

  @override
  Future<void> hapus(String id) async => tidakDidukung();

  @override
  Future<List<StatusIuran>> statusIuran() async => tidakDidukung();

  @override
  Future<void> aturIuran(AturanIuran aturan) async => tidakDidukung();
}

class PengumumanTidakDidukung implements PengumumanRepository {
  const PengumumanTidakDidukung();

  @override
  Future<List<Pengumuman>> daftar() async => tidakDidukung();

  @override
  Future<void> simpan(Pengumuman pengumuman) async => tidakDidukung();

  @override
  Future<void> hapus(String id) async => tidakDidukung();
}

class RekapTidakDidukung implements RekapRepository {
  const RekapTidakDidukung();

  @override
  Future<String?> namaKelas() async => null;

  @override
  Future<List<MahasiswaRekap>> daftarMahasiswa() async => tidakDidukung();

  @override
  Future<RekapAbsenMk> rekapAbsen(String mataKuliahId) async => tidakDidukung();

  @override
  Future<RekapTugasMk> rekapTugas(String mataKuliahId) async => tidakDidukung();
}
