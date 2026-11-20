import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/format.dart';
import 'dokumen_rekap.dart';

const _ukuranKop = 7.6;
const _ukuranKepala = 7.1;
const _tinggiKepala = 18.0;
const _tinggiBaris = 18.0;
const _garis = 0.5;
const _batasBawah = 555.0;

final _hitam = PdfColor.fromInt(0xFF000000);
final _abuGaris = PdfColor.fromInt(0xFFB0B0B0);
final _abuTeks = PdfColor.fromInt(0xFF6E6E6E);
final _waktuCetak = DateFormat('d MMMM y, HH:mm', 'id_ID');

/// Font bawaan PDF hanya memuat Latin-1, jadi tanda baca lain diganti.
String aman(String s) {
  final ganti = s
      .replaceAll(RegExp('[‐-―−]'), '-')
      .replaceAll(RegExp('[‘’]'), "'")
      .replaceAll(RegExp('[“”]'), '"')
      .replaceAll('…', '...')
      .replaceAll('•', '·');
  return String.fromCharCodes(ganti.runes.map((c) => c <= 0xFF ? c : 0x3F));
}

String _teksSel(Object v, bool rupiah) => switch (v) {
  int n when rupiah => formatRupiah(n),
  int n => '$n',
  _ => '$v',
};

/// Satu halaman: tabel mana dan potongan baris ke berapa.
class _Halaman {
  const _Halaman(this.tabel, this.awal, this.akhir);

  final TabelRekap tabel;
  final int awal;
  final int akhir;
}

/// Baris yang muat di satu halaman untuk tabel tanpa batas tetap.
int _muat(DokumenRekap d, TabelRekap t) {
  final barisInfo = d.infoKiri.length > d.infoKanan.length
      ? d.infoKiri.length
      : d.infoKanan.length;
  final atas =
      30 +
      12.4 * d.kop.baris.length +
      36 +
      12.5 * barisInfo +
      (d.dosen.isEmpty ? 0 : 26) +
      10;
  final ruang =
      _batasBawah -
      atas -
      t.jumlahBarisKepala * _tinggiKepala -
      12.0 * t.catatan.length;
  return (ruang / _tinggiBaris).floor().clamp(1, 1000);
}

List<_Halaman> _bagiHalaman(DokumenRekap d) {
  final hasil = <_Halaman>[];
  for (final t in d.tabel) {
    final per = t.barisPerHalaman ?? _muat(d, t);
    if (t.isi.isEmpty) {
      hasil.add(_Halaman(t, 0, 0));
      continue;
    }
    for (var i = 0; i < t.isi.length; i += per) {
      final akhir = i + per > t.isi.length ? t.isi.length : i + per;
      hasil.add(_Halaman(t, i, akhir));
    }
  }
  return hasil;
}

/// Jumlah halaman PDF untuk dokumen ini.
int jumlahHalamanPdf(DokumenRekap d) => _bagiHalaman(d).length;

/// Membuat PDF A4 lanskap mengikuti format daftar hadir kampus.
Future<Uint8List> buatPdf(DokumenRekap d) async {
  final tema = pw.ThemeData.withFont(
    base: pw.Font.helvetica(),
    bold: pw.Font.helveticaBold(),
    italic: pw.Font.helveticaOblique(),
    boldItalic: pw.Font.helveticaBoldOblique(),
  );
  final doc = pw.Document(
    title: aman(d.judul),
    author: 'ClassMate',
    creator: 'ClassMate',
  );
  final halaman = _bagiHalaman(d);
  for (final (i, h) in halaman.indexed) {
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(41, 30, 31, 22),
        theme: tema,
        build: (_) => _isiHalaman(d, h, i + 1, halaman.length),
      ),
    );
  }
  return doc.save();
}

pw.Widget _teks(
  String s, {
  double ukuran = _ukuranKop,
  bool tebal = false,
  bool miring = false,
  PdfColor? warna,
}) => pw.Text(
  aman(s),
  style: pw.TextStyle(
    fontSize: ukuran,
    fontWeight: tebal ? pw.FontWeight.bold : pw.FontWeight.normal,
    fontStyle: miring ? pw.FontStyle.italic : pw.FontStyle.normal,
    color: warna ?? _hitam,
  ),
);

pw.Widget _isiHalaman(DokumenRekap d, _Halaman h, int ke, int total) {
  final t = h.tabel;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      // Kop kiri dan nomor halaman kanan.
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (final b in d.kop.baris)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3.2),
                    child: _teks(b, tebal: true),
                  ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 16),
            child: _teks('Halaman $ke Dari $total'),
          ),
        ],
      ),
      pw.SizedBox(height: 1),
      pw.Center(child: _teks(t.judul ?? d.judul, tebal: true)),
      pw.SizedBox(height: 3.5),
      pw.Center(child: _teks(d.subjudul, tebal: true)),
      pw.SizedBox(height: 13),
      _info(d),
      if (d.dosen.isNotEmpty) ...[pw.SizedBox(height: 8), _kotakDosen(d)],
      pw.SizedBox(height: 10),
      _tabel(t, h.awal, h.akhir),
      if (t.catatanTiapHalaman || h.akhir >= t.isi.length)
        for (final c in t.catatan)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: _teks(c, ukuran: _ukuranKepala, miring: true),
          ),
      pw.Spacer(),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: _teks(
          'Dicetak melalui ClassMate, ${_waktuCetak.format(d.dicetak)}',
          ukuran: 6,
          warna: _abuTeks,
        ),
      ),
    ],
  );
}

pw.Widget _barisInfo((String, String)? kiri, (String, String)? kanan) {
  pw.Widget pasangan((String, String)? p, double lebarLabel) => p == null
      ? pw.SizedBox()
      : pw.Row(
          children: [
            pw.SizedBox(width: lebarLabel, child: _teks(p.$1)),
            _teks(':  '),
            pw.Expanded(child: _teks(p.$2)),
          ],
        );
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 1.8),
    decoration: pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(width: 0.3, color: _abuGaris)),
    ),
    child: pw.Row(
      children: [
        pw.SizedBox(width: 436, child: pasangan(kiri, 138)),
        pw.Expanded(child: pasangan(kanan, 115)),
      ],
    ),
  );
}

pw.Widget _info(DokumenRekap d) {
  final n = d.infoKiri.length > d.infoKanan.length
      ? d.infoKiri.length
      : d.infoKanan.length;
  return pw.Column(
    children: [
      for (var i = 0; i < n; i++)
        _barisInfo(
          i < d.infoKiri.length ? d.infoKiri[i] : null,
          i < d.infoKanan.length ? d.infoKanan[i] : null,
        ),
    ],
  );
}

pw.Widget _kotakDosen(DokumenRekap d) => pw.Container(
  decoration: pw.BoxDecoration(
    border: pw.Border.all(width: 0.8, color: _hitam),
  ),
  child: pw.Row(
    children: [
      pw.Container(
        width: 140,
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        decoration: pw.BoxDecoration(
          border: pw.Border(right: pw.BorderSide(width: 0.8, color: _hitam)),
        ),
        alignment: pw.Alignment.center,
        child: _teks(
          'DOSEN PENGASUH MATAKULIAH',
          ukuran: _ukuranKepala,
          tebal: true,
        ),
      ),
      pw.Expanded(
        child: pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: _teks(d.teksDosen, tebal: true),
        ),
      ),
    ],
  ),
);

pw.Alignment _arah(Rata r) => switch (r) {
  Rata.kiri => pw.Alignment.centerLeft,
  Rata.tengah => pw.Alignment.center,
  Rata.kanan => pw.Alignment.centerRight,
};

/// Sel bergaris atas dan kiri; garis kanan dan bawah dari bingkai tabel.
pw.Widget _sel(
  String teks, {
  required double lebar,
  required double tinggi,
  required Rata rata,
  bool tebal = false,
  double ukuran = _ukuranKop,
}) => pw.Container(
  width: lebar,
  height: tinggi,
  padding: const pw.EdgeInsets.symmetric(horizontal: 2.5),
  decoration: pw.BoxDecoration(
    border: pw.Border(
      top: pw.BorderSide(width: _garis, color: _hitam),
      left: pw.BorderSide(width: _garis, color: _hitam),
    ),
  ),
  alignment: _arah(rata),
  child: teks.isEmpty
      ? null
      : pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          alignment: _arah(rata),
          child: _teks(teks, ukuran: ukuran, tebal: tebal),
        ),
);

pw.Widget _tabel(TabelRekap t, int awal, int akhir) {
  final x = <double>[0];
  for (final l in t.lebar) {
    x.add(x.last + l);
  }
  final total = x.last;
  final kepala = pw.SizedBox(
    width: total,
    height: t.jumlahBarisKepala * _tinggiKepala,
    child: pw.Stack(
      children: [
        for (final s in t.kepala)
          pw.Positioned(
            left: x[s.kolom],
            top: s.baris * _tinggiKepala,
            child: _sel(
              s.teks,
              lebar: x[s.kolom + s.rentangKolom] - x[s.kolom],
              tinggi: s.rentangBaris * _tinggiKepala,
              rata: s.rata,
              tebal: s.tebal,
              ukuran: s.tebal ? _ukuranKepala : 6.4,
            ),
          ),
      ],
    ),
  );
  return pw.Container(
    width: total + _garis,
    decoration: pw.BoxDecoration(
      border: pw.Border(
        right: pw.BorderSide(width: _garis, color: _hitam),
        bottom: pw.BorderSide(width: _garis, color: _hitam),
      ),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        kepala,
        for (var i = awal; i < akhir; i++)
          pw.Row(
            children: [
              for (var k = 0; k < t.jumlahKolom; k++)
                _sel(
                  k < t.isi[i].length
                      ? _teksSel(t.isi[i][k], t.kolomRupiah.contains(k))
                      : '',
                  lebar: t.lebar[k],
                  tinggi: _tinggiBaris,
                  rata: t.rata[k],
                  tebal: t.barisTebal.contains(i),
                ),
            ],
          ),
      ],
    ),
  );
}
