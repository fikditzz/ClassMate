/// Bentuk dokumen rekap yang netral: dipakai bersama oleh penulis PDF dan
/// Excel, sehingga keduanya selalu berisi hal yang sama.
library;

/// Baris kop di kiri atas setiap halaman, mengikuti dokumen akademik kampus.
class KopDokumen {
  const KopDokumen({
    this.baris = const [
      'KEMENTERIAN PENDIDIKAN TINGGI, SAINS, DAN TEKNOLOGI',
      'UNIVERSITAS NEGERI MAKASSAR',
      'TEKNIK',
      'PROGRAM STUDI / KONSENTRASI : TEKNIK KOMPUTER - (S1) / GENERAL',
    ],
  });

  final List<String> baris;

  /// "SEMESTER GANJIL TAHUN AKADEMIK 2026-2027". Agustus–Januari termasuk
  /// semester ganjil, Februari–Juli semester genap.
  static String semester(DateTime t) {
    final ganjil = t.month >= 8 || t.month == 1;
    final awal = switch (t.month) {
      >= 8 => t.year,
      _ => t.year - 1,
    };
    return 'SEMESTER ${ganjil ? 'GANJIL' : 'GENAP'} '
        'TAHUN AKADEMIK $awal-${awal + 1}';
  }

  /// Huruf kelas dari nama kelas: "TEKOM A" atau "TEKOM A 2025" menjadi "A".
  static String hurufKelas(String? namaKelas) {
    if (namaKelas == null || namaKelas.trim().isEmpty) return '-';
    final kata = namaKelas.trim().split(RegExp(r'\s+'));
    for (final k in kata.reversed) {
      if (RegExp(r'^[A-Za-z]$').hasMatch(k)) return k.toUpperCase();
    }
    return namaKelas.trim().toUpperCase();
  }
}

/// Perataan teks di sel tabel.
enum Rata { kiri, tengah, kanan }

/// Sel kepala tabel; boleh merentang beberapa baris atau kolom.
class SelKepala {
  const SelKepala(
    this.baris,
    this.kolom,
    this.teks, {
    this.rentangBaris = 1,
    this.rentangKolom = 1,
    this.tebal = true,
    this.rata = Rata.tengah,
  });

  final int baris;
  final int kolom;
  final String teks;
  final int rentangBaris;
  final int rentangKolom;
  final bool tebal;
  final Rata rata;
}

/// Satu tabel. Di PDF dipecah per halaman; di Excel menjadi satu lembar.
class TabelRekap {
  TabelRekap({
    required this.namaLembar,
    required this.lebar,
    required this.jumlahBarisKepala,
    required this.kepala,
    required this.isi,
    required this.rata,
    this.judul,
    this.barisPerHalaman,
    this.catatan = const [],
    this.kolomRupiah = const {},
    this.barisTebal = const {},
    this.catatanTiapHalaman = false,
  }) : assert(lebar.length == rata.length);

  /// Nama lembar Excel (maks. 31 karakter).
  final String namaLembar;

  /// Judul halaman pengganti judul dokumen, misalnya untuk lembar
  /// rekapitulasi.
  final String? judul;

  /// Lebar kolom dalam poin PDF (total 770 untuk A4 lanskap).
  final List<double> lebar;
  final int jumlahBarisKepala;
  final List<SelKepala> kepala;

  /// Isi sel: [String] atau [int] (angka; rupiah bila kolomnya ada di
  /// [kolomRupiah]).
  final List<List<Object>> isi;
  final List<Rata> rata;

  /// Null berarti sebanyak yang muat di satu halaman.
  final int? barisPerHalaman;

  /// Baris catatan miring di bawah tabel.
  final List<String> catatan;
  final Set<int> kolomRupiah;

  /// Indeks baris isi yang dicetak tebal (misalnya baris jumlah).
  final Set<int> barisTebal;

  /// Catatan di setiap halaman; bila false hanya di halaman terakhir tabel.
  final bool catatanTiapHalaman;

  int get jumlahKolom => lebar.length;
}

/// Dokumen rekap lengkap: kop, judul, info, dosen, dan tabel-tabelnya.
class DokumenRekap {
  const DokumenRekap({
    required this.judul,
    required this.subjudul,
    required this.namaBerkas,
    required this.tabel,
    required this.dicetak,
    this.kop = const KopDokumen(),
    this.infoKiri = const [],
    this.infoKanan = const [],
    this.dosen = const [],
  });

  final String judul;
  final String subjudul;

  /// Nama berkas tanpa ekstensi.
  final String namaBerkas;
  final KopDokumen kop;

  /// Pasangan label dan nilai, misalnya ('KELAS', 'A').
  final List<(String, String)> infoKiri;
  final List<(String, String)> infoKanan;

  /// Dosen pengasuh; kotak dosen tidak dicetak bila kosong.
  final List<String> dosen;
  final List<TabelRekap> tabel;
  final DateTime dicetak;

  /// "1). Nama Dosen ; 2). Nama Dosen ;"
  String get teksDosen =>
      [for (final (i, d) in dosen.indexed) '${i + 1}). $d ;'].join(' ');
}

/// Nama berkas aman: huruf, angka, dan garis bawah.
String namaBerkasAman(String s) => s
    .trim()
    .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');
