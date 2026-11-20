import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'dokumen_rekap.dart';
import 'excel_rekap.dart';
import 'pdf_rekap.dart';

/// Format berkas ekspor.
enum FormatEkspor {
  pdf('PDF', 'pdf', 'application/pdf'),
  excel(
    'Excel',
    'xlsx',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );

  const FormatEkspor(this.label, this.ekstensi, this.mime);

  final String label;
  final String ekstensi;
  final String mime;
}

/// Membuat berkas lalu membuka lembar bagikan sistem (simpan ke Files,
/// Drive, WhatsApp, dan sebagainya).
Future<void> eksporDokumen(DokumenRekap d, FormatEkspor format) async {
  final Uint8List isi = switch (format) {
    FormatEkspor.pdf => await buatPdf(d),
    FormatEkspor.excel => buatExcel(d),
  };
  final nama = '${d.namaBerkas}.${format.ekstensi}';
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(isi, mimeType: format.mime, name: nama)],
      fileNameOverrides: [nama],
      subject: nama,
    ),
  );
}
