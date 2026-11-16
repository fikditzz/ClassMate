/// Satu slot kuliah mingguan (dokumen `jadwal/{id}`).
class Jadwal {
  const Jadwal({
    this.id = '',
    required this.mataKuliahId,
    required this.hari,
    required this.jamMulai,
    required this.jamSelesai,
    this.ruang = '',
  });

  static const daftarHari = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  /// Kosong untuk jadwal yang belum disimpan.
  final String id;
  final String mataKuliahId;

  /// 1 = Senin ... 7 = Minggu, sama dengan [DateTime.weekday].
  final int hari;

  /// Format "HH:mm".
  final String jamMulai;
  final String jamSelesai;
  final String ruang;

  String get namaHari => daftarHari[hari - 1];

  int get menitMulai => _keMenit(jamMulai);
  int get menitSelesai => _keMenit(jamSelesai);

  bool get waktuValid => menitSelesai > menitMulai;

  /// Dua jadwal bentrok bila harinya sama dan rentang waktunya beririsan.
  /// Jadwal tidak dianggap bentrok dengan dirinya sendiri (saat diedit).
  bool bentrokDengan(Jadwal lain) {
    if (id.isNotEmpty && id == lain.id) return false;
    if (hari != lain.hari) return false;
    return menitMulai < lain.menitSelesai && lain.menitMulai < menitSelesai;
  }

  int bandingkan(Jadwal lain) {
    final h = hari.compareTo(lain.hari);
    return h != 0 ? h : menitMulai.compareTo(lain.menitMulai);
  }

  Jadwal salin({String? id}) => Jadwal(
    id: id ?? this.id,
    mataKuliahId: mataKuliahId,
    hari: hari,
    jamMulai: jamMulai,
    jamSelesai: jamSelesai,
    ruang: ruang,
  );

  factory Jadwal.dariFirestore(String id, Map<String, dynamic> d) => Jadwal(
    id: id,
    mataKuliahId: (d['mata_kuliah_id'] as String?) ?? '',
    hari: (d['hari'] as num?)?.toInt() ?? 1,
    jamMulai: (d['jam_mulai'] as String?) ?? '00:00',
    jamSelesai: (d['jam_selesai'] as String?) ?? '00:00',
    ruang: (d['ruang'] as String?) ?? '',
  );

  Map<String, dynamic> keFirestore() => {
    'mata_kuliah_id': mataKuliahId,
    'hari': hari,
    'jam_mulai': jamMulai,
    'jam_selesai': jamSelesai,
    'ruang': ruang,
  };

  static int _keMenit(String jam) {
    final bagian = jam.split(':');
    return int.parse(bagian[0]) * 60 + int.parse(bagian[1]);
  }
}
