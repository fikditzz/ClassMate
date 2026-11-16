import 'konversi.dart';

/// Sesi absensi (dokumen `sesi_absensi/{id}`). Token disimpan terpisah di
/// subkoleksi `rahasia` yang hanya bisa dibaca Admin.
class SesiAbsensi {
  SesiAbsensi({
    required this.id,
    required this.mataKuliahId,
    required this.mulai,
    required this.berakhir,
    required String status,
  }) : _dibuka = status == 'buka';

  final String id;
  final String mataKuliahId;
  final DateTime mulai;
  final DateTime berakhir;
  final bool _dibuka;

  /// Sesi bisa dipakai untuk absen: dibuka admin dan masih dalam rentang waktu.
  bool masihBerlaku([DateTime? sekarang]) {
    final t = sekarang ?? DateTime.now();
    return _dibuka && !t.isBefore(mulai) && t.isBefore(berakhir);
  }

  factory SesiAbsensi.dariFirestore(String id, Map<String, dynamic> d) =>
      SesiAbsensi(
        id: id,
        mataKuliahId: (d['mata_kuliah_id'] as String?) ?? '',
        mulai: keDateTime(d['mulai']),
        berakhir: keDateTime(d['berakhir']),
        status: (d['status'] as String?) ?? 'tutup',
      );

  Map<String, dynamic> keFirestore() => {
    'mata_kuliah_id': mataKuliahId,
    'mulai': mulai,
    'berakhir': berakhir,
    'status': _dibuka ? 'buka' : 'tutup',
  };
}
