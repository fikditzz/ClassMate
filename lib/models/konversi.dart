import 'package:cloud_firestore/cloud_firestore.dart';

/// Mengubah nilai waktu dari Firestore (Timestamp), Supabase (string ISO 8601,
/// biasanya UTC), atau data demo (DateTime) menjadi [DateTime] waktu lokal.
/// Nilai `null` muncul sesaat ketika serverTimestamp belum dikonfirmasi
/// server, jadi dianggap "sekarang".
DateTime keDateTime(Object? nilai) {
  if (nilai is Timestamp) return nilai.toDate();
  if (nilai is DateTime) return nilai;
  if (nilai is String) return DateTime.parse(nilai).toLocal();
  return DateTime.now();
}
