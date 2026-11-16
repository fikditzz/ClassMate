import 'jadwal.dart';

enum JenisPerubahan {
  /// Pertemuan pada tanggal itu ditiadakan.
  libur,

  /// Pertemuan pada tanggal itu dipindah ke tanggal dan jam lain.
  pindah,

  /// Kuliah sekali di luar jadwal tetap (pengganti atau tambahan).
  tambahan,
}

DateTime tanggalSaja(DateTime t) => DateTime(t.year, t.month, t.day);

/// Perubahan satu pertemuan (tabel `perubahan_jadwal`). Jadwal tetap
/// mingguan tidak ikut berubah.
class PerubahanJadwal {
  const PerubahanJadwal({
    this.id = '',
    required this.jenis,
    required this.mataKuliahId,
    this.jadwalId,
    this.tanggalAsal,
    this.tanggal,
    this.jamMulai,
    this.jamSelesai,
    this.ruang = '',
    this.keterangan = '',
  });

  /// Kosong untuk perubahan yang belum disimpan.
  final String id;
  final JenisPerubahan jenis;
  final String mataKuliahId;

  /// Jadwal tetap yang diubah (libur dan pindah).
  final String? jadwalId;

  /// Tanggal pertemuan asal yang diubah (libur dan pindah).
  final DateTime? tanggalAsal;

  /// Tanggal kuliah yang baru (pindah dan tambahan).
  final DateTime? tanggal;

  /// Format "HH:mm" (pindah dan tambahan).
  final String? jamMulai;
  final String? jamSelesai;
  final String ruang;
  final String keterangan;
}

enum StatusPertemuan {
  /// Sesuai jadwal tetap.
  biasa,

  /// Jadwal tetap yang diliburkan pada tanggal ini.
  libur,

  /// Jadwal tetap yang dipindah dari tanggal ini ke tanggal lain.
  dipindahKeluar,

  /// Pertemuan yang dipindah ke tanggal ini.
  pengganti,

  /// Kuliah tambahan sekali di tanggal ini.
  tambahan,
}

/// Satu kuliah pada tanggal tertentu, setelah perubahan diterapkan.
class Pertemuan {
  const Pertemuan({
    required this.jadwal,
    required this.tanggal,
    required this.status,
    this.asal,
    this.perubahan,
  });

  /// Waktu dan ruang yang berlaku pada [tanggal].
  final Jadwal jadwal;
  final DateTime tanggal;
  final StatusPertemuan status;

  /// Jadwal tetap asal (kosong untuk kuliah tambahan).
  final Jadwal? asal;
  final PerubahanJadwal? perubahan;

  /// Kuliah benar-benar berlangsung pada [tanggal].
  bool get berlangsung =>
      status != StatusPertemuan.libur &&
      status != StatusPertemuan.dipindahKeluar;
}

/// Semua pertemuan pada [tanggal]: jadwal tetap di hari itu (beserta tanda
/// libur atau dipindah), ditambah pertemuan pindahan dan kuliah tambahan.
/// Diurutkan dari jam mulai.
List<Pertemuan> pertemuanPada(
  DateTime tanggal,
  List<Jadwal> jadwal,
  List<PerubahanJadwal> perubahan,
) {
  final tgl = tanggalSaja(tanggal);
  bool sama(DateTime? a) => a != null && tanggalSaja(a) == tgl;
  final hasil = <Pertemuan>[];

  for (final j in jadwal.where((j) => j.hari == tgl.weekday)) {
    final p = perubahan
        .where((p) => p.jadwalId == j.id && sama(p.tanggalAsal))
        .firstOrNull;
    hasil.add(
      Pertemuan(
        jadwal: j,
        tanggal: tgl,
        asal: j,
        perubahan: p,
        status: switch (p?.jenis) {
          null || JenisPerubahan.tambahan => StatusPertemuan.biasa,
          JenisPerubahan.libur => StatusPertemuan.libur,
          JenisPerubahan.pindah => StatusPertemuan.dipindahKeluar,
        },
      ),
    );
  }

  for (final p in perubahan) {
    if (p.jenis == JenisPerubahan.libur || !sama(p.tanggal)) continue;
    final asal = p.jadwalId == null
        ? null
        : jadwal.where((j) => j.id == p.jadwalId).firstOrNull;
    // Pindahan yang jadwal asalnya sudah dihapus tidak ditampilkan.
    if (p.jenis == JenisPerubahan.pindah && asal == null) continue;
    hasil.add(
      Pertemuan(
        jadwal: Jadwal(
          id: 'perubahan-${p.id}',
          mataKuliahId: p.mataKuliahId,
          hari: tgl.weekday,
          jamMulai: p.jamMulai ?? '00:00',
          jamSelesai: p.jamSelesai ?? '00:00',
          ruang: p.ruang.isNotEmpty ? p.ruang : (asal?.ruang ?? ''),
        ),
        tanggal: tgl,
        asal: asal,
        perubahan: p,
        status: p.jenis == JenisPerubahan.pindah
            ? StatusPertemuan.pengganti
            : StatusPertemuan.tambahan,
      ),
    );
  }

  hasil.sort((a, b) {
    final w = a.jadwal.menitMulai.compareTo(b.jadwal.menitMulai);
    if (w != 0) return w;
    // Yang berlangsung di atas yang libur atau dipindah.
    return (a.berlangsung ? 0 : 1).compareTo(b.berlangsung ? 0 : 1);
  });
  return hasil;
}

/// Pertemuan lain yang berlangsung pada tanggal [baru] dan jamnya beririsan.
/// [abaikan] berisi pertemuan yang sedang diubah sendiri.
List<Jadwal> bentrokPada(
  DateTime tanggal,
  Jadwal baru,
  List<Jadwal> jadwal,
  List<PerubahanJadwal> perubahan, {
  String? abaikanJadwalId,
  String? abaikanPerubahanId,
}) {
  return [
    for (final p in pertemuanPada(tanggal, jadwal, perubahan))
      if (p.berlangsung &&
          (abaikanJadwalId == null ||
              p.status != StatusPertemuan.biasa ||
              p.jadwal.id != abaikanJadwalId) &&
          (abaikanPerubahanId == null ||
              p.perubahan?.id != abaikanPerubahanId) &&
          p.jadwal.menitMulai < baru.menitSelesai &&
          baru.menitMulai < p.jadwal.menitSelesai)
        p.jadwal,
  ];
}
