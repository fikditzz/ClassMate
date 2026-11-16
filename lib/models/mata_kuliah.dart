/// Dokumen `mata_kuliah/{id}`.
class MataKuliah {
  const MataKuliah({
    required this.id,
    required this.nama,
    this.kelasId,
    this.kode = '',
    this.sks = 0,
    this.dosen = const [],
  });

  final String id;
  final String nama;
  final String? kelasId;

  /// Kode mata kuliah, misalnya "21B01C307".
  final String kode;
  final int sks;

  /// Dosen pengampu di urutan pertama, diikuti dosen mitra.
  final List<String> dosen;

  String? get dosenPengampu => dosen.isEmpty ? null : dosen.first;

  factory MataKuliah.dariFirestore(String id, Map<String, dynamic> d) =>
      MataKuliah(
        id: id,
        nama: (d['nama'] as String?) ?? id,
        kelasId: d['kelas_id'] as String?,
        kode: (d['kode'] as String?) ?? '',
        sks: (d['sks'] as num?)?.toInt() ?? 0,
        dosen: [for (final x in (d['dosen'] as List?) ?? const []) '$x'],
      );

  Map<String, dynamic> keFirestore() => {
    'nama': nama,
    'kelas_id': kelasId,
    'kode': kode,
    'sks': sks,
    'dosen': dosen,
  };
}
