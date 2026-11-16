/// Konfigurasi proyek Supabase ClassMate.
///
/// Publishable key memang boleh disimpan di aplikasi: siapa pun yang
/// memegangnya hanya mendapat akses yang diizinkan RLS di database
/// (lihat `supabase/migrations`). Jangan pernah menaruh secret key atau
/// service_role key di sini.
abstract final class SupabaseOptions {
  static const url = 'https://smifusynzjyqpdhmmooz.supabase.co';
  static const publishableKey =
      'sb_publishable_BotHEMFPLVMjqMUVCoCtHA_G4BYdcvc';

  /// OAuth Client ID bertipe "Web application" dari Google Cloud Console.
  /// ID token Google dibuat untuk client ini, lalu diperiksa Supabase.
  /// Daftarkan juga di Supabase: Authentication → Sign In / Providers → Google.
  static const googleWebClientId = '';

  /// OAuth Client ID bertipe "iOS". Hanya dipakai di build iOS.
  static const googleIosClientId = '';

  /// Selama URL atau key masih kosong, aplikasi berjalan dalam mode demo.
  /// Login email + password langsung bisa dipakai; tombol Google muncul
  /// setelah [googleWebClientId] diisi.
  static bool get sudahLengkap => url.isNotEmpty && publishableKey.isNotEmpty;
}
