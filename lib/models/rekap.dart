/// Data rekap untuk dokumen daftar hadir dan pengumpulan tugas.
library;

/// Mahasiswa di dokumen rekap (urut stambuk, lalu nama).
class MahasiswaRekap {
  const MahasiswaRekap({
    required this.id,
    required this.nama,
    required this.stambuk,
  });

  final String id;
  final String nama;

  /// Nomor stambuk/NIM. Diisi dari username akun bila NIM tidak tersedia.
  final String stambuk;

  static int urutkan(MahasiswaRekap a, MahasiswaRekap b) {
    final s = a.stambuk.compareTo(b.stambuk);
    return s != 0 ? s : a.nama.compareTo(b.nama);
  }
}

/// Satu pertemuan (sesi absen) yang sudah terlaksana.
class PertemuanRekap {
  const PertemuanRekap({required this.sesiId, required this.tanggal});

  final String sesiId;
  final DateTime tanggal;
}

/// Isi satu sel daftar hadir.
enum IsiSel {
  /// Pertemuan belum terlaksana.
  kosong(''),
  hadir('H'),
  tidakHadir('A'),

  /// Kolom ujian (UTS/UAS) yang tidak dicatat lewat absen kelas.
  ujian('-');

  const IsiSel(this.teks);

  final String teks;
}

/// Rekap daftar hadir satu mata kuliah, mengikuti format daftar hadir
/// kampus: kolom 1–7, UTS, 8–14, UAS.
class RekapAbsenMk {
  RekapAbsenMk({
    required this.mataKuliahId,
    required List<MahasiswaRekap> mahasiswa,
    required List<PertemuanRekap> pertemuan,
    required Set<(String sesiId, String userId)> hadir,
  }) : mahasiswa = [...mahasiswa]..sort(MahasiswaRekap.urutkan),
       pertemuan = [...pertemuan]
         ..sort((a, b) => a.tanggal.compareTo(b.tanggal)),
       _daftarHadir = hadir;

  final String mataKuliahId;
  final List<MahasiswaRekap> mahasiswa;

  /// Urut tanggal; hanya pertemuan yang sudah terlaksana.
  final List<PertemuanRekap> pertemuan;
  final Set<(String, String)> _daftarHadir;

  /// Label 16 kolom pertemuan.
  static const labelKolom = [
    '1', '2', '3', '4', '5', '6', '7', 'UTS', //
    '8', '9', '10', '11', '12', '13', '14', 'UAS',
  ];

  static const _indeksUts = 7, _indeksUas = 15;

  /// Pertemuan kuliah maksimal di tabel (di luar UTS dan UAS).
  static const maksPertemuan = 14;

  static bool kolomUjian(int kolom) =>
      kolom == _indeksUts || kolom == _indeksUas;

  /// Pertemuan pada kolom ke-[kolom] (0..15), atau null untuk kolom ujian
  /// dan pertemuan yang belum terlaksana.
  PertemuanRekap? pertemuanKolom(int kolom) {
    if (kolomUjian(kolom)) return null;
    final ke = kolom < _indeksUts ? kolom : kolom - 1;
    return ke < pertemuan.length ? pertemuan[ke] : null;
  }

  /// Pertemuan yang tidak muat di 14 kolom (dilaporkan di catatan).
  int get pertemuanLebih =>
      pertemuan.length > maksPertemuan ? pertemuan.length - maksPertemuan : 0;

  bool hadir(String sesiId, String userId) =>
      _daftarHadir.contains((sesiId, userId));

  IsiSel sel(int kolom, String userId) {
    if (kolomUjian(kolom)) return IsiSel.ujian;
    final p = pertemuanKolom(kolom);
    if (p == null) return IsiSel.kosong;
    return hadir(p.sesiId, userId) ? IsiSel.hadir : IsiSel.tidakHadir;
  }

  int jumlahHadir(String userId) =>
      pertemuan.where((p) => hadir(p.sesiId, userId)).length;

  /// 0..1, atau null bila belum ada pertemuan.
  double? persen(String userId) =>
      pertemuan.isEmpty ? null : jumlahHadir(userId) / pertemuan.length;

  /// Rata-rata kehadiran seluruh mahasiswa, atau null.
  double? get rataRata {
    if (pertemuan.isEmpty || mahasiswa.isEmpty) return null;
    final total = mahasiswa.fold<int>(0, (s, m) => s + jumlahHadir(m.id));
    return total / (pertemuan.length * mahasiswa.length);
  }
}

/// Tugas dalam rekap pengumpulan.
class TugasRekap {
  const TugasRekap({
    required this.id,
    required this.judul,
    required this.tenggat,
  });

  final String id;
  final String judul;
  final DateTime tenggat;
}

/// Rekap pengumpulan tugas satu mata kuliah.
class RekapTugasMk {
  RekapTugasMk({
    required this.mataKuliahId,
    required List<MahasiswaRekap> mahasiswa,
    required List<TugasRekap> tugas,
    required Set<(String tugasId, String userId)> terkumpul,
  }) : mahasiswa = [...mahasiswa]..sort(MahasiswaRekap.urutkan),
       tugas = [...tugas]..sort((a, b) => a.tenggat.compareTo(b.tenggat)),
       _daftarKumpul = terkumpul;

  final String mataKuliahId;
  final List<MahasiswaRekap> mahasiswa;
  final List<TugasRekap> tugas;
  final Set<(String, String)> _daftarKumpul;

  bool terkumpul(String tugasId, String userId) =>
      _daftarKumpul.contains((tugasId, userId));

  int jumlahTerkumpul(String userId) =>
      tugas.where((t) => terkumpul(t.id, userId)).length;

  /// Mahasiswa yang sudah mengumpulkan satu tugas.
  int pengumpulTugas(String tugasId) =>
      mahasiswa.where((m) => terkumpul(tugasId, m.id)).length;
}
