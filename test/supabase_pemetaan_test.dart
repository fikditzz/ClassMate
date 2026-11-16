import 'package:classmate/data/supabase/pemetaan.dart';
import 'package:classmate/models/jadwal.dart';
import 'package:classmate/models/konversi.dart';
import 'package:classmate/models/pengguna.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WITA', () {
    test('tanggal + jam WITA menjadi waktu yang benar', () {
      final t = dariWita('2026-11-16', '07:30:00');
      expect(t.toUtc(), DateTime.utc(2026, 11, 15, 23, 30));
    });

    test('waktu menjadi tanggal dan jam WITA, termasuk lewat tengah malam', () {
      final w = keWita(DateTime.utc(2026, 11, 15, 23, 30));
      expect(w.tanggal, '2026-11-16');
      expect(w.jam, '07:30:00');
    });

    test('bolak-balik tidak mengubah waktu', () {
      final awal = DateTime.utc(2026, 2, 28, 16, 5, 9);
      final w = keWita(awal);
      expect(dariWita(w.tanggal, w.jam).toUtc(), awal);
    });

    test('jam dengan pecahan detik tetap terbaca', () {
      expect(
        dariWita('2026-11-16', '23:59:59.5').toUtc(),
        DateTime.utc(2026, 11, 16, 15, 59, 59),
      );
    });
  });

  test('jam, hari, dan waktu ISO', () {
    expect(jamPendek('07:30:00'), '07:30');
    expect(jamPendek('07:30'), '07:30');
    expect(hariDariNama('Senin'), 1);
    expect(hariDariNama('Minggu'), 7);
    expect(namaHari(3), 'Rabu');
    expect(
      keDateTime('2026-11-15T10:00:00+00:00').toUtc(),
      DateTime.utc(2026, 11, 15, 10),
    );
    expect(keDateTime('2026-11-15T10:00:00+00:00').isUtc, isFalse);
  });

  test('jadwal dari baris Supabase dan kembali lagi', () {
    final j = jadwalDari({
      'id': 12,
      'mata_kuliah_id': 3,
      'hari': 'Selasa',
      'jam_mulai': '10:05:00',
      'jam_selesai': '12:40:00',
      'ruang': null,
    });
    expect(j.id, '12');
    expect(j.mataKuliahId, '3');
    expect(j.hari, 2);
    expect(j.jamMulai, '10:05');
    expect(j.ruang, '');
    expect(jadwalKeBaris(j), {
      'mata_kuliah_id': 3,
      'hari': 'Selasa',
      'jam_mulai': '10:05',
      'jam_selesai': '12:40',
      'ruang': null,
    });
    expect(
      jadwalKeBaris(
        const Jadwal(
          mataKuliahId: '3',
          hari: 7,
          jamMulai: '08:00',
          jamSelesai: '09:00',
          ruang: 'AE 109',
        ),
      )['hari'],
      'Minggu',
    );
  });

  test('status sesi aktif menjadi buka, lainnya tutup', () {
    final baris = {
      'id': 5,
      'mata_kuliah_id': 1,
      'tanggal': '2026-11-16',
      'jam_mulai': '07:30:00',
      'jam_selesai': '09:00:00',
    };
    final saatKuliah = DateTime.utc(2026, 11, 16, 0); // 08:00 WITA
    expect(
      sesiDari({...baris, 'status': 'aktif'}).masihBerlaku(saatKuliah),
      isTrue,
    );
    expect(
      sesiDari({...baris, 'status': 'ditutup'}).masihBerlaku(saatKuliah),
      isFalse,
    );
    expect(
      sesiDari({...baris, 'status': 'dibatalkan'}).masihBerlaku(saatKuliah),
      isFalse,
    );
    expect(sesiDari({...baris, 'status': 'aktif'}).id, '5');
  });

  test('mata kuliah dengan daftar dosen', () {
    final mk = mataKuliahDari({
      'id': 1,
      'kelas_id': 2,
      'nama': 'Pemrograman Web',
      'kode': '21B01C307',
      'sks': 3,
      'dosen': ['A', 'B'],
    });
    expect(mk.id, '1');
    expect(mk.kelasId, '2');
    expect(mk.dosenPengampu, 'A');
    expect(
      mataKuliahDari({'id': 4, 'nama': 'X', 'dosen': null}).dosen,
      isEmpty,
    );
  });

  test('peran dosen diperlakukan seperti admin', () {
    final d = Pengguna.dariData(
      uid: '7',
      email: 'Dosen@Kampus.ac.id',
      data: {'nama': 'Bu Dosen', 'peran': 'dosen'},
    );
    expect(d, isA<Dosen>());
    expect(d.isAdmin, isTrue);
    expect(d.peran, 'dosen');
    expect(d.labelPeran, 'Dosen');
    expect(d.email, 'dosen@kampus.ac.id');

    final m = Pengguna.dariData(
      uid: '8',
      email: 'mhs@kampus.ac.id',
      data: {'peran': 'mahasiswa'},
    );
    expect(m, isA<Anggota>());
    expect(m.isAdmin, isFalse);
  });
}
