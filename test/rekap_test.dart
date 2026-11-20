import 'package:classmate/app.dart';
import 'package:classmate/data/demo/demo_backend.dart';
import 'package:classmate/ekspor/dokumen_rekap.dart';
import 'package:classmate/ekspor/excel_rekap.dart';
import 'package:classmate/ekspor/isi_rekap.dart';
import 'package:classmate/ekspor/pdf_rekap.dart';
import 'package:classmate/models/kas.dart';
import 'package:classmate/models/mata_kuliah.dart';
import 'package:classmate/models/pengguna.dart';
import 'package:classmate/models/rekap.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _mk = MataKuliah(
  id: 'plj',
  nama: 'Pemrograman Lanjut',
  kode: '21B01C301',
  sks: 3,
  dosen: ['Dosen Satu, S.Kom., M.Kom.', 'Dosen Dua, S.T., M.T.'],
);

List<MahasiswaRekap> _mahasiswa(int n) => [
  for (var i = n; i >= 1; i--)
    MahasiswaRekap(id: 'u$i', nama: 'Mahasiswa $i', stambuk: '25${1000 + i}'),
];

RekapAbsenMk _rekap({int pertemuan = 9, int mahasiswa = 3}) => RekapAbsenMk(
  mataKuliahId: 'plj',
  mahasiswa: _mahasiswa(mahasiswa),
  pertemuan: [
    for (var i = pertemuan - 1; i >= 0; i--)
      PertemuanRekap(sesiId: 's$i', tanggal: DateTime(2026, 9, 1 + 7 * i)),
  ],
  // u1 hadir semua, u2 hadir di pertemuan genap, u3 tidak pernah.
  hadir: {
    for (var i = 0; i < pertemuan; i++) ('s$i', 'u1'),
    for (var i = 0; i < pertemuan; i += 2) ('s$i', 'u2'),
  },
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('RekapAbsenMk', () {
    test('kolom 1-7, UTS, 8-14, UAS dipetakan ke pertemuan berurutan', () {
      final r = _rekap();
      expect(r.mahasiswa.map((m) => m.id), ['u1', 'u2', 'u3']);
      expect(r.pertemuanKolom(0)!.sesiId, 's0');
      expect(r.pertemuanKolom(6)!.sesiId, 's6');
      expect(r.pertemuanKolom(7), isNull);
      expect(r.pertemuanKolom(8)!.sesiId, 's7');
      expect(r.pertemuanKolom(9)!.sesiId, 's8');
      expect(r.pertemuanKolom(10), isNull);
      expect(r.sel(7, 'u1'), IsiSel.ujian);
      expect(r.sel(15, 'u1'), IsiSel.ujian);
      expect(r.sel(8, 'u3'), IsiSel.tidakHadir);
      expect(r.sel(10, 'u1'), IsiSel.kosong);
    });

    test('jumlah hadir, persen, dan rata-rata', () {
      final r = _rekap();
      expect(r.jumlahHadir('u1'), 9);
      expect(r.jumlahHadir('u2'), 5);
      expect(r.persen('u3'), 0);
      expect(r.rataRata, closeTo(14 / 27, 1e-9));
      expect(_rekap(pertemuan: 0).persen('u1'), isNull);
      expect(_rekap(pertemuan: 16).pertemuanLebih, 2);
    });
  });

  group('KopDokumen', () {
    test('semester mengikuti bulan', () {
      expect(
        KopDokumen.semester(DateTime(2026, 11, 20)),
        'SEMESTER GANJIL TAHUN AKADEMIK 2026-2027',
      );
      expect(
        KopDokumen.semester(DateTime(2027, 1, 10)),
        'SEMESTER GANJIL TAHUN AKADEMIK 2026-2027',
      );
      expect(
        KopDokumen.semester(DateTime(2027, 3, 1)),
        'SEMESTER GENAP TAHUN AKADEMIK 2026-2027',
      );
    });

    test('huruf kelas dari nama kelas', () {
      expect(KopDokumen.hurufKelas('TEKOM A'), 'A');
      expect(KopDokumen.hurufKelas('TEKOM B 2025'), 'B');
      expect(KopDokumen.hurufKelas(null), '-');
    });
  });

  group('dokumen', () {
    const info = InfoMk(mataKuliah: _mk, kelas: 'A');

    test('daftar hadir: 15 mahasiswa per halaman plus rekapitulasi', () {
      final d = dokumenDaftarHadir(
        _rekap(mahasiswa: 20),
        info,
        dicetak: DateTime(2026, 11, 20),
      );
      expect(d.namaBerkas, 'Daftar_Hadir_Pemrograman_Lanjut_Kelas_A');
      expect(d.teksDosen, startsWith('1). Dosen Satu'));
      expect(d.infoKiri.first.$2, '21B01C301 / PEMROGRAMAN LANJUT / 3');
      final daftar = d.tabel.first;
      expect(daftar.jumlahKolom, 19);
      expect(daftar.lebar.fold(0.0, (a, b) => a + b), closeTo(770, 0.01));
      expect(daftar.isi.first.sublist(0, 4), [1, '251001', 'MAHASISWA 1', 'H']);
      // 20 mahasiswa: daftar hadir 15 + 5, rekapitulasi 19 + 1.
      expect(jumlahHalamanPdf(d), 4);
    });

    test('PDF dan Excel terbentuk', () async {
      final d = dokumenDaftarHadir(_rekap(), info);
      final pdf = await buatPdf(d);
      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');

      final xlsx = Excel.decodeBytes(buatExcel(d));
      expect(xlsx.tables.keys, containsAll(['Daftar Hadir', 'Rekapitulasi']));
      final lembar = xlsx.tables['Daftar Hadir']!;
      final teks = [
        for (final baris in lembar.rows)
          for (final c in baris)
            if (c?.value != null) '${c!.value}',
      ];
      expect(teks, contains('DAFTAR HADIR MAHASISWA DAN DOSEN'));
      expect(teks, contains('UAS'));
      expect(teks, contains('MAHASISWA 3'));
    });

    test('rekap tugas dan laporan kas', () async {
      final tugas = dokumenRekapTugas(
        RekapTugasMk(
          mataKuliahId: 'plj',
          mahasiswa: _mahasiswa(2),
          tugas: [
            TugasRekap(id: 't1', judul: 'Tugas 1', tenggat: DateTime(2026, 9)),
          ],
          terkumpul: {('t1', 'u1')},
        ),
        info,
      );
      expect(tugas.tabel.single.isi.first.sublist(3), ['Sudah', '1/1']);
      expect(tugas.tabel.single.isi.last.sublist(3), ['Belum', '0/1']);

      final kas = dokumenKas(
        riwayat: [
          TransaksiKas(
            id: 'a',
            jenis: JenisKas.pemasukan,
            jumlah: 50000,
            tanggal: DateTime(2026, 9, 1),
            keterangan: 'Donasi',
          ),
          TransaksiKas(
            id: 'b',
            jenis: JenisKas.pengeluaran,
            jumlah: 20000,
            tanggal: DateTime(2026, 9, 2),
            keterangan: 'Spidol',
          ),
        ],
        status: const [],
        ringkasan: const RingkasanKas(
          saldo: 30000,
          masukBulanIni: 0,
          keluarBulanIni: 0,
        ),
        namaKelas: 'TEKOM A',
      );
      final buku = kas.tabel.single;
      expect(buku.isi.last, ['', '', 'JUMLAH', '', 50000, 20000, 30000]);
      expect(String.fromCharCodes((await buatPdf(kas)).take(5)), '%PDF-');
    });

    test('teks PDF dibatasi Latin-1', () {
      expect(aman('1–10 “uji” − ok'), '1-10 "uji" - ok');
      expect(aman('ابc'), '??c');
    });
  });

  group('demo', () {
    test('rekap absen demo hanya untuk pengelola', () async {
      final backend = DemoBackend();
      final admin = backend.buatRepositori(
        Pengguna.dariData(
          uid: 'demo-admin',
          email: 'a@demo',
          data: {'peran': 'admin'},
        ),
      );
      final r = await admin.rekap.rekapAbsen('pweb');
      expect(r.mahasiswa.length, greaterThan(15));
      expect(r.pertemuan, isNotEmpty);

      final anggota = backend.buatRepositori(
        Pengguna.dariData(
          uid: 'demo-anggota',
          email: 'b@demo',
          data: {'peran': 'mahasiswa'},
        ),
      );
      expect(anggota.rekap.rekapAbsen('pweb'), throwsA(anything));
    });
  });

  testWidgets('Admin membuka Rekap & Ekspor dari beranda', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ClassMateApp(backend: DemoBackend(), fontInter: false),
    );
    await tester.pump();
    await tester.tap(find.text('Masuk sebagai Admin'));
    await tester.pump();
    await tester.pump();

    final menu = find.text('Rekap').first;
    await tester.ensureVisible(menu);
    await tester.pump();
    await tester.tap(menu);
    await tester.pumpAndSettle();

    expect(find.text('Rekap & Ekspor'), findsOneWidget);
    expect(find.text('Unduh PDF'), findsOneWidget);
    expect(find.text('Unduh Excel'), findsOneWidget);
    expect(find.text('RATA-RATA KEHADIRAN'), findsOneWidget);

    await tester.tap(find.text('Kas'));
    await tester.pumpAndSettle();
    expect(find.text('Status iuran'), findsOneWidget);
  });
}
