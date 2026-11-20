import 'konversi.dart';

/// Pengumuman kelas dari admin atau dosen (tabel `pengumuman`).
class Pengumuman {
  const Pengumuman({
    this.id = '',
    required this.judul,
    this.isi = '',
    this.penting = false,
    this.namaPembuat,
    DateTime? dibuatPada,
    // Parameter bernama tidak bisa privat, jadi field diisi di sini.
    // ignore: prefer_initializing_formals
  }) : _dibuatPada = dibuatPada;

  /// Kosong untuk pengumuman yang belum disimpan.
  final String id;
  final String judul;
  final String isi;

  /// Ditandai penting: tampil menonjol di beranda.
  final bool penting;
  final String? namaPembuat;
  final DateTime? _dibuatPada;

  DateTime get dibuatPada => _dibuatPada ?? DateTime.now();

  /// Masih dianggap baru (ditandai di daftar).
  bool baru([DateTime? sekarang]) =>
      (sekarang ?? DateTime.now()).difference(dibuatPada) <
      const Duration(days: 2);

  Pengumuman salin({String? judul, String? isi, bool? penting}) => Pengumuman(
    id: id,
    judul: judul ?? this.judul,
    isi: isi ?? this.isi,
    penting: penting ?? this.penting,
    namaPembuat: namaPembuat,
    dibuatPada: _dibuatPada,
  );

  factory Pengumuman.dariMap(Map<String, dynamic> r) => Pengumuman(
    id: '${r['id']}',
    judul: (r['judul'] as String?) ?? '(tanpa judul)',
    isi: (r['isi'] as String?) ?? '',
    penting: r['penting'] == true,
    namaPembuat: r['nama_pembuat'] as String?,
    dibuatPada: keDateTime(r['dibuat_pada']),
  );
}
