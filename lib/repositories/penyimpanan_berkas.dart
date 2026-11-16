/// Hasil unggahan berkas tugas.
class BerkasTerunggah {
  const BerkasTerunggah({
    required this.fileId,
    required this.url,
    required this.nama,
    required this.ukuran,
  });

  final String fileId;
  final String url;
  final String nama;
  final int ukuran;
}

/// Kontrak penyimpanan berkas tugas. Implementasi yang direncanakan:
/// `GoogleDriveStorage` (Google Drive API v3 milik akun yang login).
///
/// TODO: buat GoogleDriveStorage dengan paket `googleapis` + `file_picker`.
abstract class PenyimpananBerkas {
  /// Batas ukuran sementara (PRD: 10–20 MB, masih pertanyaan terbuka).
  static const batasUkuranByte = 20 * 1024 * 1024;

  /// Mengunggah berkas baru, atau mengganti [gantiFileId] bila diisi.
  Future<BerkasTerunggah> unggah({
    required String namaFile,
    required List<int> isi,
    String? gantiFileId,
  });

  Future<void> hapus(String fileId);
}
