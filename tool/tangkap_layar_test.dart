// Memotret setiap halaman (mode demo) ke PNG untuk memeriksa layout tanpa
// perangkat. Font: Roboto + Material Icons dari Flutter SDK.
//
//   flutter test tool/tangkap_layar_test.dart --dart-define=TANGKAP_DIR=<folder>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:classmate/app.dart';
import 'package:classmate/data/demo/demo_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _dir = String.fromEnvironment(
  'TANGKAP_DIR',
  defaultValue: 'build/tangkap',
);
final _kunci = GlobalKey();

Future<void> _muatFont() async {
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? r'C:\flutter';
  final dir = '$sdk/bin/cache/artifacts/material_fonts';
  Future<void> muat(String keluarga, List<String> file) async {
    final loader = FontLoader(keluarga);
    for (final f in file) {
      final b = File('$dir/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(b.buffer)));
    }
    await loader.load();
  }

  await muat('Roboto', [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
  ]);
  await muat('MaterialIcons', ['materialicons-regular.otf']);
}

Future<void> _buka(WidgetTester t, {double tinggi = 844}) async {
  t.view.physicalSize = Size(390 * 2, tinggi * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    RepaintBoundary(
      key: _kunci,
      child: ClassMateApp(backend: DemoBackend(), fontInter: false),
    ),
  );
  await _tunggu(t);
}

Future<void> _tunggu(WidgetTester t, [int ms = 1200]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _ketuk(WidgetTester t, Finder f) async {
  await t.ensureVisible(f.first);
  await t.pump();
  await t.tap(f.first, warnIfMissed: false);
  await _tunggu(t);
}

Future<void> _foto(WidgetTester t, String nama) async {
  await t.runAsync(() async {
    final b =
        _kunci.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$_dir/$nama.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    await _muatFont();
  });

  testWidgets('01 login', (t) async {
    await _buka(t);
    await _foto(t, '01_login');
  });

  testWidgets('02 anggota', (t) async {
    await _buka(t, tinggi: 1500);
    await _ketuk(t, find.text('Masuk sebagai Anggota'));
    await _foto(t, '02_beranda');
    await _ketuk(t, find.text('Absensi').last);
    await _foto(t, '03_absensi');
    await t.enterText(find.byType(TextField), 'SALAH1');
    await _tunggu(t);
    await _foto(t, '04_absensi_salah');
    await t.enterText(find.byType(TextField), 'KLS123');
    await _tunggu(t);
    await _foto(t, '05_absensi_berhasil');
    await _ketuk(t, find.text('Tugas').last);
    await _foto(t, '06_tugas');
    await _ketuk(t, find.text('Landing page responsif'));
    await _foto(t, '07_tugas_detail');
    Navigator.of(t.element(find.text('Instruksi Pengerjaan'))).pop();
    await _tunggu(t);
    await _ketuk(t, find.text('Jadwal').last);
    // Strip tanggal bergeser ke hari ini; geser balik ke awal minggu.
    await t.drag(find.text('Rab').first, const Offset(400, 0));
    await _tunggu(t);
    await _ketuk(t, find.text('Sel'));
    await _foto(t, '08_jadwal_harian');
    await _ketuk(t, find.text('Mingguan'));
    await _foto(t, '09_jadwal_mingguan');
    await _ketuk(t, find.text('Profil').last);
    await _foto(t, '10_profil');
  });

  testWidgets('03 admin', (t) async {
    await _buka(t, tinggi: 1500);
    await _ketuk(t, find.text('Masuk sebagai Admin'));
    await _foto(t, '11_admin_beranda');
    await _ketuk(t, find.text('Absensi').last);
    await _foto(t, '12_admin_absensi');
    await _ketuk(t, find.text('Tugas').last);
    await _foto(t, '13_admin_tugas');
    await _ketuk(t, find.text('Jadwal').last);
    await _ketuk(t, find.text('Tambah Jadwal'));
    await _foto(t, '14_admin_form_jadwal');
  });

  testWidgets('04 fitur kas, pengumuman, kehadiran', (t) async {
    await _buka(t, tinggi: 1700);
    await _ketuk(t, find.text('Masuk sebagai Anggota'));
    await _foto(t, '15_beranda_baru');
    await _ketuk(t, find.text('Uang Kas'));
    await _foto(t, '16_kas_anggota');
    Navigator.of(t.element(find.text('SALDO KAS KELAS'))).pop();
    await _tunggu(t);
    await _ketuk(t, find.text('Pengumuman').last);
    await _foto(t, '17_pengumuman');
    Navigator.of(t.element(find.text('Kuis Matematika Diskrit pekan depan'))).pop();
    await _tunggu(t);
    await _ketuk(t, find.text('Kehadiran').last);
    await _foto(t, '18_rekap_kehadiran');
  });

  testWidgets('05 kas admin', (t) async {
    await _buka(t, tinggi: 1700);
    await _ketuk(t, find.text('Masuk sebagai Admin'));
    await _ketuk(t, find.text('Uang Kas'));
    await _foto(t, '19_kas_admin_riwayat');
    await _ketuk(t, find.text('Status Iuran'));
    await _foto(t, '20_kas_admin_status');
    await _ketuk(t, find.text('Catat Transaksi'));
    await _foto(t, '21_kas_admin_form');
  });

  testWidgets('06 rekap dan ekspor', (t) async {
    await _buka(t, tinggi: 1700);
    await _ketuk(t, find.text('Masuk sebagai Admin'));
    await _ketuk(t, find.text('Rekap'));
    await _foto(t, '22_rekap_hadir');
    await _ketuk(t, find.text('Tugas').last);
    await _foto(t, '23_rekap_tugas');
    await _ketuk(t, find.text('Kas').last);
    await _foto(t, '24_rekap_kas');
  });
}
