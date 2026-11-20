import 'konversi.dart';

/// Jenis transaksi di tabel `kas_transaksi`.
enum JenisKas {
  /// Iuran rutin dari anggota (selalu terkait satu anggota).
  iuran('Iuran'),

  /// Uang masuk selain iuran: donasi, sisa acara, dsb.
  pemasukan('Pemasukan'),

  /// Uang keluar dari kas kelas.
  pengeluaran('Pengeluaran');

  const JenisKas(this.label);

  final String label;

  bool get masuk => this != pengeluaran;

  /// Membaca nilai kolom `jenis` secara toleran (data lama bisa memakai
  /// "masuk"/"keluar" atau huruf besar).
  static JenisKas dari(Object? nilai) {
    final s = '${nilai ?? ''}'.trim().toLowerCase();
    return switch (s) {
      'pengeluaran' || 'keluar' || 'out' => pengeluaran,
      'iuran' => iuran,
      _ => pemasukan,
    };
  }
}

/// Satu baris riwayat kas. Untuk anggota biasa, iuran dari banyak orang di
/// tanggal yang sama digabung menjadi satu baris ([jumlahAnggota] > 0) tanpa
/// nama, agar status bayar orang lain tidak terlihat.
class TransaksiKas {
  const TransaksiKas({
    this.id = '',
    required this.jenis,
    required this.jumlah,
    required this.tanggal,
    this.keterangan = '',
    this.userId,
    this.namaAnggota,
    this.jumlahAnggota = 0,
  });

  /// Kosong untuk transaksi baru atau baris iuran gabungan.
  final String id;
  final JenisKas jenis;

  /// Rupiah, selalu positif; arah ditentukan [jenis].
  final int jumlah;
  final DateTime tanggal;
  final String keterangan;

  /// Anggota yang membayar (khusus iuran).
  final String? userId;
  final String? namaAnggota;

  /// Banyaknya iuran yang digabung (0 = bukan baris gabungan).
  final int jumlahAnggota;

  bool get gabungan => jumlahAnggota > 0;

  /// Nilai bertanda: positif untuk uang masuk, negatif untuk keluar.
  int get nilai => jenis.masuk ? jumlah : -jumlah;

  /// Judul yang ditampilkan di daftar.
  String get judul {
    if (gabungan) return 'Iuran kas ($jumlahAnggota anggota)';
    if (keterangan.trim().isNotEmpty) return keterangan.trim();
    if (jenis == JenisKas.iuran && namaAnggota != null) {
      return 'Iuran $namaAnggota';
    }
    return jenis.label;
  }

  factory TransaksiKas.dariMap(Map<String, dynamic> r) => TransaksiKas(
    id: r['id'] == null ? '' : '${r['id']}',
    jenis: JenisKas.dari(r['jenis']),
    jumlah: ((r['jumlah'] as num?) ?? 0).abs().round(),
    tanggal: keDateTime(r['tanggal']),
    keterangan: (r['keterangan'] as String?) ?? '',
    userId: r['user_id']?.toString(),
    namaAnggota: r['nama_anggota'] as String?,
    jumlahAnggota: (r['jumlah_anggota'] as num?)?.toInt() ?? 0,
  );
}

/// Pengaturan iuran mingguan kelas.
class AturanIuran {
  const AturanIuran({required this.nominal, required this.mulai});

  /// Rupiah per pekan.
  final int nominal;

  /// Pekan pertama iuran.
  final DateTime mulai;

  /// Pekan ke berapa sekarang (1 = pekan pertama). 0 bila belum mulai.
  int pekanBerjalan([DateTime? sekarang]) {
    final n = sekarang ?? DateTime.now();
    final awal = DateTime(mulai.year, mulai.month, mulai.day);
    final hari = DateTime(n.year, n.month, n.day).difference(awal).inDays;
    if (hari < 0) return 0;
    return hari ~/ 7 + 1;
  }

  /// Total iuran yang seharusnya sudah dibayar sampai pekan ini.
  int target([DateTime? sekarang]) => pekanBerjalan(sekarang) * nominal;
}

/// Ringkasan kas kelas yang boleh dilihat semua anggota.
class RingkasanKas {
  const RingkasanKas({
    required this.saldo,
    required this.masukBulanIni,
    required this.keluarBulanIni,
    this.aturan,
  });

  final int saldo;
  final int masukBulanIni;
  final int keluarBulanIni;

  /// Null bila admin belum mengatur iuran mingguan.
  final AturanIuran? aturan;

  int get selisihBulanIni => masukBulanIni - keluarBulanIni;

  static RingkasanKas dariTransaksi(
    List<TransaksiKas> semua, {
    AturanIuran? aturan,
    DateTime? sekarang,
  }) {
    final n = sekarang ?? DateTime.now();
    var saldo = 0, masuk = 0, keluar = 0;
    for (final t in semua) {
      saldo += t.nilai;
      if (t.tanggal.year == n.year && t.tanggal.month == n.month) {
        if (t.jenis.masuk) {
          masuk += t.jumlah;
        } else {
          keluar += t.jumlah;
        }
      }
    }
    return RingkasanKas(
      saldo: saldo,
      masukBulanIni: masuk,
      keluarBulanIni: keluar,
      aturan: aturan,
    );
  }
}

/// Status iuran satu anggota (untuk admin, atau untuk diri sendiri).
class StatusIuran {
  const StatusIuran({
    required this.userId,
    required this.nama,
    required this.totalBayar,
    this.kaliBayar = 0,
    this.terakhir,
  });

  final String userId;
  final String nama;
  final int totalBayar;
  final int kaliBayar;
  final DateTime? terakhir;

  /// Kekurangan terhadap target aturan iuran (0 bila lunas atau belum ada
  /// aturan).
  int tunggakan(AturanIuran? aturan, [DateTime? sekarang]) {
    if (aturan == null) return 0;
    final kurang = aturan.target(sekarang) - totalBayar;
    return kurang > 0 ? kurang : 0;
  }

  /// Banyaknya pekan yang sudah tertutup oleh total pembayaran.
  int pekanLunas(AturanIuran? aturan) {
    if (aturan == null || aturan.nominal <= 0) return kaliBayar;
    return totalBayar ~/ aturan.nominal;
  }
}
