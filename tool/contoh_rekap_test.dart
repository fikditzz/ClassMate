// Membuat contoh berkas rekap (PDF dan Excel) dari data demo untuk
// memeriksa tata letak tanpa perangkat. Nama mahasiswa di data demo fiktif.
//
//   flutter test tool/contoh_rekap_test.dart --dart-define=REKAP_DIR=<folder>
import 'dart:io';

import 'package:classmate/data/demo/demo_backend.dart';
import 'package:classmate/data/demo/jadwal_tekom_a_2025.dart';
import 'package:classmate/ekspor/dokumen_rekap.dart';
import 'package:classmate/ekspor/excel_rekap.dart';
import 'package:classmate/ekspor/isi_rekap.dart';
import 'package:classmate/ekspor/pdf_rekap.dart';
import 'package:classmate/models/pengguna.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _dir = String.fromEnvironment('REKAP_DIR', defaultValue: 'build/rekap');

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('buat contoh rekap', () async {
    final repo = DemoBackend().buatRepositori(
      Pengguna.dariData(
        uid: 'demo-admin',
        email: 'ketua@kelas.demo',
        data: {'nama': 'Raka Pratama', 'peran': 'admin'},
      ),
    );
    final mk = mataKuliahTekomA2025.firstWhere((m) => m.id == 'pweb');
    final info = InfoMk(
      mataKuliah: mk,
      kelas: KopDokumen.hurufKelas(await repo.rekap.namaKelas()),
      jadwal: jadwalTekomA2025.where((j) => j.mataKuliahId == mk.id).toList(),
    );
    final dokumen = [
      dokumenDaftarHadir(await repo.rekap.rekapAbsen(mk.id), info),
      dokumenRekapTugas(await repo.rekap.rekapTugas(mk.id), info),
      dokumenKas(
        riwayat: await repo.kas.riwayatKelas(),
        status: await repo.kas.statusIuran(),
        ringkasan: await repo.kas.ringkasan(),
        namaKelas: 'TEKOM A',
      ),
    ];
    Directory(_dir).createSync(recursive: true);
    for (final d in dokumen) {
      File('$_dir/${d.namaBerkas}.pdf').writeAsBytesSync(await buatPdf(d));
      File('$_dir/${d.namaBerkas}.xlsx').writeAsBytesSync(buatExcel(d));
    }
  });
}
