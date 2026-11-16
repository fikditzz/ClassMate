import 'konversi.dart';

/// Dokumen `tugas/{id}`.
class Tugas {
  const Tugas({
    this.id = '',
    required this.mataKuliahId,
    required this.judul,
    this.deskripsi = '',
    required this.tenggat,
    this.dibuatOleh = '',
  });

  final String id;
  final String mataKuliahId;
  final String judul;
  final String deskripsi;
  final DateTime tenggat;
  final String dibuatOleh;

  bool sudahLewatTenggat([DateTime? sekarang]) =>
      !(sekarang ?? DateTime.now()).isBefore(tenggat);

  /// Belum lewat tenggat dan tenggatnya dalam [rentang] ke depan.
  bool mendekatiTenggat(Duration rentang, [DateTime? sekarang]) {
    final t = sekarang ?? DateTime.now();
    return !sudahLewatTenggat(t) && tenggat.isBefore(t.add(rentang));
  }

  factory Tugas.dariFirestore(String id, Map<String, dynamic> d) => Tugas(
    id: id,
    mataKuliahId: (d['mata_kuliah_id'] as String?) ?? '',
    judul: (d['judul'] as String?) ?? '(tanpa judul)',
    deskripsi: (d['deskripsi'] as String?) ?? '',
    tenggat: keDateTime(d['tenggat']),
    dibuatOleh: (d['dibuat_oleh'] as String?) ?? '',
  );

  Map<String, dynamic> keFirestore() => {
    'mata_kuliah_id': mataKuliahId,
    'judul': judul,
    'deskripsi': deskripsi,
    'tenggat': tenggat,
    'dibuat_oleh': dibuatOleh,
  };
}
