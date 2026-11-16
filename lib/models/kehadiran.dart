import 'konversi.dart';

/// Dokumen `kehadiran/{sesiId_uid}`. Sekali dibuat tidak bisa diubah.
class Kehadiran {
  const Kehadiran({
    required this.sesiId,
    required this.uid,
    required this.email,
    required this.waktuAbsen,
  });

  final String sesiId;
  final String uid;
  final String email;
  final DateTime waktuAbsen;

  static String idDokumen(String sesiId, String uid) => '${sesiId}_$uid';

  factory Kehadiran.dariFirestore(Map<String, dynamic> d) => Kehadiran(
    sesiId: (d['sesi_id'] as String?) ?? '',
    uid: (d['uid'] as String?) ?? '',
    email: (d['email'] as String?) ?? '',
    waktuAbsen: keDateTime(d['waktu_absen']),
  );
}
