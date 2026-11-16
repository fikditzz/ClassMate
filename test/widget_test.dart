import 'package:classmate/app.dart';
import 'package:classmate/data/demo/demo_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> _bukaApp(WidgetTester tester) async {
  // Ukuran layar ponsel acuan desain (390 x 844).
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ClassMateApp(backend: DemoBackend(), fontInter: false),
  );
  await tester.pump();
}

Future<void> _ketuk(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('Anggota: token salah ditolak, token benar tercatat', (
    tester,
  ) async {
    await _bukaApp(tester);
    await _ketuk(tester, find.text('Masuk sebagai Anggota'));

    expect(find.text('Sinta Maharani'), findsOneWidget);
    expect(find.text('Buat Sesi'), findsNothing);
    expect(find.text('Sesi Presensi Dibuka'), findsOneWidget);

    await _ketuk(tester, find.text('Absensi').last);
    expect(find.text('Masukkan 6 Digit Token Presensi'), findsOneWidget);

    // Token terkirim otomatis begitu 6 karakter terisi.
    await tester.enterText(find.byType(TextField), 'SALAH1');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Token salah atau sesi sudah berakhir.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'kls123');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Presensi Berhasil Dicatat!'), findsOneWidget);

    await _ketuk(tester, find.text('Kembali ke Beranda'));
    await _ketuk(tester, find.text('Absensi').last);
    expect(find.text('Kamu sudah absen di sesi ini'), findsOneWidget);
  });

  testWidgets('Admin: menu admin dan token sesi tampil', (tester) async {
    await _bukaApp(tester);
    await _ketuk(tester, find.text('Masuk sebagai Admin'));

    expect(find.text('Lihat Token Sesi'), findsOneWidget);
    expect(find.text('Beranda Admin Kelas'), findsOneWidget);

    await _ketuk(tester, find.text('Absensi').last);
    await tester.pump();
    expect(find.text('K L S 1 2 3'), findsOneWidget);
    expect(find.text('Tutup Sesi Presensi Sekarang'), findsOneWidget);
  });

  testWidgets('Tab Tugas, Jadwal, dan Profil terbuka', (tester) async {
    await _bukaApp(tester);
    await _ketuk(tester, find.text('Masuk sebagai Anggota'));

    await _ketuk(tester, find.text('Tugas').last);
    expect(find.text('Landing page responsif'), findsOneWidget);

    await _ketuk(tester, find.text('Landing page responsif'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Instruksi Pengerjaan'), findsOneWidget);
    Navigator.of(tester.element(find.text('Instruksi Pengerjaan'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Instruksi Pengerjaan'), findsNothing);

    await _ketuk(tester, find.text('Jadwal').last);
    expect(find.text('Harian'), findsOneWidget);
    await _ketuk(tester, find.text('Mingguan'));
    expect(find.text('Minggu Ini'), findsOneWidget);

    await _ketuk(tester, find.text('Profil').last);
    expect(find.text('Ganti password'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Keluar dari Akun'), 200);
    expect(find.text('Keluar dari Akun'), findsOneWidget);
    // Anggota tidak melihat menu administrasi.
    expect(find.text('Kelola akun'), findsNothing);
  });

  testWidgets('Admin: kelola akun dan liburkan satu pertemuan', (tester) async {
    await _bukaApp(tester);
    await _ketuk(tester, find.text('Masuk sebagai Admin'));

    await _ketuk(tester, find.text('Profil').last);
    await _ketuk(tester, find.text('Kelola akun'));
    await tester.pumpAndSettle();
    expect(find.text('Sinta Maharani'), findsOneWidget);
    expect(find.text('Belum punya password'), findsOneWidget);
    Navigator.of(tester.element(find.text('Kelola Akun'))).pop();
    await tester.pumpAndSettle();

    // Senin minggu ini selalu punya kuliah Pemrograman Web di data demo.
    await _ketuk(tester, find.text('Jadwal').last);
    await _ketuk(tester, find.text('Mingguan'));
    await _ketuk(tester, find.text('Pemrograman Web').first);
    await tester.pumpAndSettle();
    expect(find.text('Pindahkan pertemuan ini'), findsOneWidget);
    await _ketuk(tester, find.text('Liburkan pertemuan ini'));
    await tester.pumpAndSettle();
    await _ketuk(tester, find.text('Liburkan Pertemuan').last);
    await tester.pumpAndSettle();
    expect(find.text('Libur'), findsWidgets);
    expect(find.text('Pertemuan ini ditiadakan'), findsOneWidget);
  });
}
