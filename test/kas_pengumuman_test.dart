import 'package:classmate/app.dart';
import 'package:classmate/data/demo/demo_backend.dart';
import 'package:classmate/models/kas.dart';
import 'package:classmate/models/pengumuman.dart';
import 'package:classmate/models/rekap_kehadiran.dart';
import 'package:classmate/pages/kas_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> _bukaApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ClassMateApp(backend: DemoBackend(), fontInter: false),
  );
  await tester.pump();
}

Future<void> _tunggu(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _ketuk(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.first);
  await _tunggu(tester);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('Aturan iuran', () {
    final aturan = AturanIuran(nominal: 10000, mulai: DateTime(2026, 11, 2));

    test('pekan berjalan dihitung dari tanggal mulai', () {
      expect(aturan.pekanBerjalan(DateTime(2026, 11, 1)), 0);
      expect(aturan.pekanBerjalan(DateTime(2026, 11, 2)), 1);
      expect(aturan.pekanBerjalan(DateTime(2026, 11, 8, 23)), 1);
      expect(aturan.pekanBerjalan(DateTime(2026, 11, 9)), 2);
      expect(aturan.target(DateTime(2026, 11, 20)), 30000);
    });

    test('tunggakan dan pekan lunas', () {
      const s = StatusIuran(userId: '1', nama: 'A', totalBayar: 20000);
      final hari = DateTime(2026, 11, 20); // pekan ke-3
      expect(s.tunggakan(aturan, hari), 10000);
      expect(s.pekanLunas(aturan), 2);
      expect(
        const StatusIuran(
          userId: '1',
          nama: 'A',
          totalBayar: 50000,
        ).tunggakan(aturan, hari),
        0,
      );
      expect(s.tunggakan(null), 0);
    });
  });

  test('jenis kas dibaca toleran dan saldo dihitung bertanda', () {
    expect(JenisKas.dari('Keluar'), JenisKas.pengeluaran);
    expect(JenisKas.dari('masuk'), JenisKas.pemasukan);
    expect(JenisKas.dari('IURAN'), JenisKas.iuran);

    final n = DateTime(2026, 11, 20);
    final r = RingkasanKas.dariTransaksi([
      TransaksiKas(jenis: JenisKas.iuran, jumlah: 10000, tanggal: n),
      TransaksiKas(jenis: JenisKas.pemasukan, jumlah: 50000, tanggal: n),
      TransaksiKas(jenis: JenisKas.pengeluaran, jumlah: 15000, tanggal: n),
      TransaksiKas(
        jenis: JenisKas.pengeluaran,
        jumlah: 5000,
        tanggal: DateTime(2026, 10, 3),
      ),
    ], sekarang: n);
    expect(r.saldo, 40000);
    expect(r.masukBulanIni, 60000);
    expect(r.keluarBulanIni, 15000);
  });

  test('baris iuran gabungan tidak menyebut nama', () {
    final t = TransaksiKas.dariMap({
      'id': null,
      'jenis': 'iuran',
      'jumlah': 30000,
      'tanggal': '2026-11-17',
      'jumlah_anggota': 3,
    });
    expect(t.gabungan, isTrue);
    expect(t.judul, 'Iuran kas (3 anggota)');
    expect(t.id, '');
  });

  test('rekap kehadiran per mata kuliah', () {
    final r = RekapKehadiran.hitung(
      mataKuliahPerSesi: {'s1': 'a', 's2': 'a', 's3': 'b', 's4': 'b'},
      sesiDihadiri: {'s1', 's3', 's4'},
    );
    expect(r.totalSesi, 4);
    expect(r.hadir, 3);
    expect(r.persen, 0.75);
    // Yang paling rendah di atas.
    expect(r.perMataKuliah.first.mataKuliahId, 'a');
    expect(const RekapKehadiran([]).persen, isNull);
  });

  test('pengumuman baru dalam dua hari', () {
    final n = DateTime(2026, 11, 20, 12);
    final p = Pengumuman(judul: 'A', dibuatPada: DateTime(2026, 11, 19));
    expect(p.baru(n), isTrue);
    expect(
      Pengumuman(judul: 'B', dibuatPada: DateTime(2026, 11, 10)).baru(n),
      isFalse,
    );
  });

  testWidgets('Anggota: beranda menampilkan pengumuman, kas, dan kehadiran', (
    tester,
  ) async {
    await _bukaApp(tester);
    await _ketuk(tester, find.text('Masuk sebagai Anggota'));

    expect(find.text('Kuis Matematika Diskrit pekan depan'), findsOneWidget);
    expect(find.text('Kas Kelas'), findsOneWidget);
    expect(find.text('Kehadiran'), findsWidgets);

    await _ketuk(tester, find.text('Uang Kas'));
    expect(find.text('SALDO KAS KELAS'), findsOneWidget);
    expect(find.text('Iuran Saya'), findsOneWidget);
    // Anggota tidak melihat nama pembayar iuran orang lain.
    expect(find.textContaining('Bima'), findsNothing);
    // Iuran orang lain tampil sebagai baris gabungan; gulir ke riwayat.
    await tester.dragUntilVisible(
      find.textContaining('Iuran kas ('),
      find
          .descendant(
            of: find.byType(KasPage),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, -300),
    );
    expect(find.textContaining('Iuran kas ('), findsWidgets);
    expect(find.text('Catat Transaksi'), findsNothing);
  });

  testWidgets('Admin: status iuran anggota dan catat pengeluaran', (
    tester,
  ) async {
    await _bukaApp(tester);
    await _ketuk(tester, find.text('Masuk sebagai Admin'));
    await _ketuk(tester, find.text('Uang Kas'));

    await _ketuk(tester, find.text('Status Iuran'));
    expect(find.text('Bima Saputra'), findsOneWidget);
    expect(find.text('−Rp40.000'), findsOneWidget); // 4 dari 8 pekan

    await _ketuk(tester, find.text('Riwayat'));
    await _ketuk(tester, find.text('Catat Transaksi'));
    await _ketuk(tester, find.text('Pengeluaran').last);
    await tester.enterText(find.widgetWithText(TextField, 'Nominal'), '25000');
    await tester.enterText(
      find.byType(TextField).last,
      'Beli kabel HDMI kelas',
    );
    await tester.pump();
    await _ketuk(tester, find.text('Simpan Transaksi'));
    expect(find.text('Beli kabel HDMI kelas'), findsOneWidget);
  });

  testWidgets('Anggota: rekap kehadiran per mata kuliah', (tester) async {
    await _bukaApp(tester);
    await _ketuk(tester, find.text('Masuk sebagai Anggota'));
    await _ketuk(tester, find.text('Kehadiran').last);
    expect(find.text('Rekap Kehadiran'), findsOneWidget);
    expect(find.text('Per mata kuliah'), findsOneWidget);
    expect(find.text('Pemrograman Web'), findsWidgets);
  });
}
