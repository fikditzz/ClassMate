import '../../core/errors.dart';
import '../../models/akun.dart';
import '../../repositories/akun_repository.dart';

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
