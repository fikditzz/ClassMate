import 'package:intl/intl.dart';

final _tanggalJam = DateFormat('EEE, d MMM • HH:mm', 'id_ID');
final _jam = DateFormat('HH:mm', 'id_ID');
final _tanggalPanjang = DateFormat('EEEE, d MMMM y', 'id_ID');
final _tanggalPendek = DateFormat('EEE, d MMM', 'id_ID');
final _hariSingkat = DateFormat('EEE', 'id_ID');
final _hariTanggal = DateFormat('EEEE, d MMM', 'id_ID');

String formatTanggalJam(DateTime t) => _tanggalJam.format(t);
String formatJam(DateTime t) => _jam.format(t);
String formatTanggalPanjang(DateTime t) => _tanggalPanjang.format(t);
String formatHariSingkat(DateTime t) => _hariSingkat.format(t);
String formatHariTanggal(DateTime t) => _hariTanggal.format(t);

/// "Hari ini, 23:59", "Besok, 17:00", atau "Jum, 25 Okt, 15:00".
String formatTenggat(DateTime t, [DateTime? sekarang]) {
  final n = sekarang ?? DateTime.now();
  final selisih = DateTime(
    t.year,
    t.month,
    t.day,
  ).difference(DateTime(n.year, n.month, n.day)).inDays;
  final jam = formatJam(t);
  return switch (selisih) {
    0 => 'Hari ini, $jam',
    1 => 'Besok, $jam',
    -1 => 'Kemarin, $jam',
    _ => '${_tanggalPendek.format(t)}, $jam',
  };
}

/// Teks singkat sisa waktu menuju [batas], misalnya "3 jam lagi".
String sisaWaktu(DateTime batas, [DateTime? sekarang]) {
  final selisih = batas.difference(sekarang ?? DateTime.now());
  if (selisih.isNegative) return 'Sudah lewat';
  if (selisih.inDays >= 1) return '${selisih.inDays} hari lagi';
  if (selisih.inHours >= 1) return '${selisih.inHours} jam lagi';
  if (selisih.inMinutes >= 1) return '${selisih.inMinutes} menit lagi';
  return 'Kurang dari 1 menit';
}

/// "1 hari 8 jam", "3 jam 12 mnt", atau "11 mnt 42 dtk".
String formatDurasi(Duration d) {
  if (d.isNegative) return '0 dtk';
  if (d.inDays >= 1) return '${d.inDays} hari ${d.inHours % 24} jam';
  if (d.inHours >= 1) return '${d.inHours} jam ${d.inMinutes % 60} mnt';
  return '${d.inMinutes} mnt ${d.inSeconds % 60} dtk';
}

/// "09:39" (menit:detik), atau "1:09:39" bila lebih dari satu jam.
String formatHitungMundur(Duration d) {
  if (d.isNegative) return '00:00';
  String dua(int n) => n.toString().padLeft(2, '0');
  final m = dua(d.inMinutes % 60), s = dua(d.inSeconds % 60);
  return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
}

/// Durasi dari menit, misalnya 100 → "1j 40m".
String formatLamaMenit(int menit) {
  final j = menit ~/ 60, m = menit % 60;
  if (j == 0) return '${m}m';
  return m == 0 ? '${j}j' : '${j}j ${m}m';
}

String formatUkuran(int byte) {
  if (byte >= 1024 * 1024) {
    return '${(byte / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (byte >= 1024) return '${(byte / 1024).toStringAsFixed(0)} KB';
  return '$byte B';
}

/// Dua huruf awal nama untuk avatar, misalnya "Sinta Maharani" → "SM".
String inisial(String nama) {
  final kata = nama
      .trim()
      .split(RegExp(r'[\s._@]+'))
      .where((k) => k.isNotEmpty);
  return kata.take(2).map((k) => k[0].toUpperCase()).join();
}

final _rupiah = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);
final _bulanTahun = DateFormat('MMMM y', 'id_ID');

/// 150000 menjadi "Rp150.000".
String formatRupiah(int nilai) => _rupiah.format(nilai);

/// Rupiah bertanda untuk arus kas: "+Rp10.000" atau "−Rp45.000".
String formatRupiahBertanda(int nilai) =>
    nilai < 0 ? '−${formatRupiah(-nilai)}' : '+${formatRupiah(nilai)}';

/// "November 2026".
String formatBulanTahun(DateTime t) => _bulanTahun.format(t);

/// "Baru saja", "15 menit lalu", "3 jam lalu", "Kemarin", atau tanggal.
String formatRelatif(DateTime t, [DateTime? sekarang]) {
  final n = sekarang ?? DateTime.now();
  final d = n.difference(t);
  if (d.isNegative || d.inMinutes < 1) return 'Baru saja';
  if (d.inHours < 1) return '${d.inMinutes} menit lalu';
  final hari = DateTime(
    n.year,
    n.month,
    n.day,
  ).difference(DateTime(t.year, t.month, t.day)).inDays;
  if (hari == 0) return '${d.inHours} jam lalu';
  if (hari == 1) return 'Kemarin, ${formatJam(t)}';
  if (hari < 7) return '$hari hari lalu';
  return _tanggalPendek.format(t);
}

final _tanggalSingkat = DateFormat('d MMM', 'id_ID');
final _tanggalSingkatTahun = DateFormat('d MMM y', 'id_ID');

/// Tanggal tanpa jam: "Hari ini", "Kemarin", "28 Sep", atau "28 Sep 2025"
/// bila beda tahun.
String formatTanggalSingkat(DateTime t, [DateTime? sekarang]) {
  final n = sekarang ?? DateTime.now();
  final selisih = DateTime(
    n.year,
    n.month,
    n.day,
  ).difference(DateTime(t.year, t.month, t.day)).inDays;
  if (selisih == 0) return 'Hari ini';
  if (selisih == 1) return 'Kemarin';
  return t.year == n.year
      ? _tanggalSingkat.format(t)
      : _tanggalSingkatTahun.format(t);
}
