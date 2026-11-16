import 'konversi.dart';

/// Dokumen `pengumpulan/{tugasId_uid}`. Berkasnya ada di Google Drive milik
/// mahasiswa; Firestore hanya menyimpan metadatanya.
class Pengumpulan {
  const Pengumpulan({
    required this.tugasId,
    required this.uid,
    required this.email,
    required this.driveFileId,
    required this.driveUrl,
    required this.namaFile,
    required this.ukuran,
    required this.waktuUpload,
  });

  final String tugasId;
  final String uid;
  final String email;
  final String driveFileId;
  final String driveUrl;
  final String namaFile;
  final int ukuran;
  final DateTime waktuUpload;

  static String idDokumen(String tugasId, String uid) => '${tugasId}_$uid';

  factory Pengumpulan.dariFirestore(Map<String, dynamic> d) => Pengumpulan(
    tugasId: (d['tugas_id'] as String?) ?? '',
    uid: (d['uid'] as String?) ?? '',
    email: (d['email'] as String?) ?? '',
    driveFileId: (d['drive_file_id'] as String?) ?? '',
    driveUrl: (d['drive_url'] as String?) ?? '',
    namaFile: (d['nama_file'] as String?) ?? '',
    ukuran: (d['ukuran'] as num?)?.toInt() ?? 0,
    waktuUpload: keDateTime(d['waktu_upload']),
  );
}
