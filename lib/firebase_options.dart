// File SEMENTARA.
//
// Jalankan `flutterfire configure` di folder proyek untuk menggantinya dengan
// konfigurasi proyek Firebase yang asli. Selama file ini belum diganti,
// aplikasi otomatis berjalan dalam mode demo (data contoh di memori).
import 'package:firebase_core/firebase_core.dart';

import 'core/errors.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform =>
      throw const FirebaseBelumDikonfigurasi();
}
