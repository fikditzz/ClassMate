import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/pengguna.dart';
import '../backend.dart';
import 'pemetaan.dart';
import 'supabase_absensi_repository.dart';
import 'supabase_akun_repository.dart';
import 'supabase_auth_repository.dart';
import 'supabase_jadwal_repository.dart';
import 'supabase_kas_repository.dart';
import 'supabase_pengumuman_repository.dart';
import 'supabase_tugas_repository.dart';

/// Backend Supabase: Auth (login Google), Postgres dengan RLS, dan Realtime.
/// Aturan keamanannya ada di `supabase/migrations`.
class SupabaseBackend implements BackendClassMate {
  SupabaseBackend(this._db) : auth = SupabaseAuthRepository(_db);

  final SupabaseClient _db;

  @override
  final SupabaseAuthRepository auth;

  @override
  bool get modeDemo => false;

  @override
  RepositoriPengguna buatRepositori(Pengguna pengguna) {
    final email = PencariEmail(_db);
    return RepositoriPengguna(
      absensi: SupabaseAbsensiRepository(_db, pengguna, email),
      tugas: SupabaseTugasRepository(_db, pengguna, email),
      jadwal: SupabaseJadwalRepository(_db),
      akun: SupabaseAkunRepository(_db),
      kas: SupabaseKasRepository(_db, pengguna),
      pengumuman: SupabasePengumumanRepository(_db),
    );
  }
}
