import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import 'dokumen_rekap.dart';

final _waktuCetak = DateFormat('d MMMM y, HH:mm', 'id_ID');
final _tipis = Border(borderStyle: BorderStyle.Thin);

HorizontalAlign _arah(Rata r) => switch (r) {
  Rata.kiri => HorizontalAlign.Left,
  Rata.tengah => HorizontalAlign.Center,
  Rata.kanan => HorizontalAlign.Right,
};

CellStyle _gaya({
  bool tebal = false,
  bool miring = false,
  int ukuran = 9,
  Rata rata = Rata.kiri,
  bool garis = false,
  bool bungkus = false,
  NumFormat format = NumFormat.standard_0,
}) => CellStyle(
  bold: tebal,
  italic: miring,
  fontSize: ukuran,
  fontFamily: 'Arial',
  horizontalAlign: _arah(rata),
  verticalAlign: VerticalAlign.Center,
  textWrapping: bungkus ? TextWrapping.WrapText : null,
  leftBorder: garis ? _tipis : null,
  rightBorder: garis ? _tipis : null,
  topBorder: garis ? _tipis : null,
  bottomBorder: garis ? _tipis : null,
  numberFormat: format,
);

CellIndex _i(int kolom, int baris) =>
    CellIndex.indexByColumnRow(columnIndex: kolom, rowIndex: baris);

void _tulis(Sheet s, int kolom, int baris, CellValue? nilai, CellStyle gaya) {
  final c = s.cell(_i(kolom, baris));
  c.value = nilai;
  c.cellStyle = gaya;
}

/// Menggabung sel lalu memberi gaya ke semua sel di dalamnya, agar garis
/// tepi sel gabungan tetap utuh.
void _gabung(
  Sheet s,
  int k1,
  int b1,
  int k2,
  int b2,
  CellValue? nilai,
  CellStyle gaya,
) {
  _tulis(s, k1, b1, nilai, gaya);
  if (k1 == k2 && b1 == b2) return;
  s.merge(_i(k1, b1), _i(k2, b2));
  for (var b = b1; b <= b2; b++) {
    for (var k = k1; k <= k2; k++) {
      if (b == b1 && k == k1) continue;
      s.cell(_i(k, b)).cellStyle = gaya;
    }
  }
}

/// Satu lembar per tabel, semua baris dalam satu tabel (tanpa dipecah
/// halaman). Kop, judul, info, dan dosen sama dengan versi PDF.
Uint8List buatExcel(DokumenRekap d) {
  final excel = Excel.createExcel();
  final bawaan = excel.getDefaultSheet() ?? 'Sheet1';
  final dipakai = <String>{};

  for (final (urut, t) in d.tabel.indexed) {
    var nama = t.namaLembar.length > 31
        ? t.namaLembar.substring(0, 31)
        : t.namaLembar;
    while (dipakai.contains(nama)) {
      nama = '$nama ${dipakai.length}';
    }
    dipakai.add(nama);
    if (urut == 0) {
      excel.rename(bawaan, nama);
    }
    _isiLembar(excel[nama], d, t);
  }
  if (dipakai.isNotEmpty) excel.setDefaultSheet(dipakai.first);
  return Uint8List.fromList(excel.encode() ?? const []);
}

void _isiLembar(Sheet s, DokumenRekap d, TabelRekap t) {
  final kolomAkhir = t.jumlahKolom - 1;
  for (final (k, l) in t.lebar.indexed) {
    s.setColumnWidth(k, (l / 5.2).clamp(4.0, 60.0));
  }

  var b = 0;
  for (final baris in d.kop.baris) {
    _tulis(s, 0, b++, TextCellValue(baris), _gaya(tebal: true));
  }
  b++;
  _gabung(
    s,
    0,
    b,
    kolomAkhir,
    b,
    TextCellValue(t.judul ?? d.judul),
    _gaya(tebal: true, ukuran: 11, rata: Rata.tengah),
  );
  b++;
  _gabung(
    s,
    0,
    b,
    kolomAkhir,
    b,
    TextCellValue(d.subjudul),
    _gaya(tebal: true, rata: Rata.tengah),
  );
  b += 2;

  // Info kiri di kolom pertama, info kanan mulai sekitar 57% lebar tabel.
  final total = t.lebar.fold(0.0, (a, x) => a + x);
  var kolomKanan = 0;
  for (var acc = 0.0; kolomKanan < t.jumlahKolom; kolomKanan++) {
    if (acc >= total * 0.57) break;
    acc += t.lebar[kolomKanan];
  }
  final n = d.infoKiri.length > d.infoKanan.length
      ? d.infoKiri.length
      : d.infoKanan.length;
  for (var i = 0; i < n; i++) {
    if (i < d.infoKiri.length) {
      final (label, nilai) = d.infoKiri[i];
      _tulis(s, 0, b, TextCellValue('$label : $nilai'), _gaya());
    }
    if (i < d.infoKanan.length && kolomKanan < t.jumlahKolom) {
      final (label, nilai) = d.infoKanan[i];
      _tulis(s, kolomKanan, b, TextCellValue('$label : $nilai'), _gaya());
    }
    b++;
  }
  if (d.dosen.isNotEmpty) {
    b++;
    _tulis(
      s,
      0,
      b++,
      TextCellValue('DOSEN PENGASUH MATAKULIAH : ${d.teksDosen}'),
      _gaya(tebal: true),
    );
  }
  b++;

  // Kepala tabel.
  final awalKepala = b;
  for (var r = 0; r < t.jumlahBarisKepala; r++) {
    s.setRowHeight(awalKepala + r, 18);
  }
  for (final k in t.kepala) {
    _gabung(
      s,
      k.kolom,
      awalKepala + k.baris,
      k.kolom + k.rentangKolom - 1,
      awalKepala + k.baris + k.rentangBaris - 1,
      k.teks.isEmpty ? null : TextCellValue(k.teks),
      _gaya(
        tebal: k.tebal,
        ukuran: k.tebal ? 9 : 8,
        rata: k.rata,
        garis: true,
        bungkus: true,
      ),
    );
  }
  b += t.jumlahBarisKepala;

  // Isi.
  for (final (i, baris) in t.isi.indexed) {
    final tebal = t.barisTebal.contains(i);
    for (var k = 0; k < t.jumlahKolom; k++) {
      final v = k < baris.length ? baris[k] : '';
      final rupiah = t.kolomRupiah.contains(k);
      _tulis(
        s,
        k,
        b,
        switch (v) {
          int n => IntCellValue(n),
          String x when x.isEmpty => null,
          _ => TextCellValue('$v'),
        },
        _gaya(
          tebal: tebal,
          rata: t.rata[k],
          garis: true,
          format: rupiah && v is int
              ? NumFormat.standard_3
              : NumFormat.standard_0,
        ),
      );
    }
    s.setRowHeight(b, 16);
    b++;
  }

  for (final c in t.catatan) {
    _tulis(s, 0, b++, TextCellValue(c), _gaya(miring: true, ukuran: 8));
  }
  b++;
  _tulis(
    s,
    0,
    b,
    TextCellValue(
      'Dicetak melalui ClassMate, ${_waktuCetak.format(d.dicetak)}',
    ),
    _gaya(miring: true, ukuran: 8),
  );
}
