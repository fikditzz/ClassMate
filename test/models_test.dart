import 'package:classmate/models/jadwal.dart';
import 'package:classmate/models/pengguna.dart';
import 'package:classmate/models/sesi_absensi.dart';
import 'package:classmate/models/tugas.dart';
import 'package:classmate/repositories/absensi_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Pengguna.dariData', () {
    test('memilih Admin atau Anggota dari field peran', () {
      final admin = Pengguna.dariData(
        uid: '1',
        email: 'Ketua@Kampus.ac.id',
        data: {'peran': 'admin', 'nama': 'A', 'username': 'a'},
      );
      final anggota = Pengguna.dariData(
        uid: '2',
        email: 'm@kampus.ac.id',
        data: {'peran': 'anggota', 'nama': 'B', 'username': 'b'},
      );

      expect(admin, isA<Admin>());
      expect(admin.email, 'ketua@kampus.ac.id');
      expect(admin.menuUtama, contains(MenuItem.buatSesi));
      expect(anggota, isA<Anggota>());
      expect(anggota.menuUtama, [
        MenuItem.absen,
        MenuItem.tugasSaya,
        MenuItem.jadwal,
        MenuItem.kas,
        MenuItem.pengumuman,
        MenuItem.kehadiran,
      ]);
      // Uang kas hanya untuk pengurus kelas, bukan dosen.
      expect(admin.menuUtama, contains(MenuItem.kas));
    });
  });

  group('Jadwal.bentrokDengan', () {
    const a = Jadwal(
      id: 'a',
      mataKuliahId: 'x',
      hari: 1,
      jamMulai: '08:00',
      jamSelesai: '09:40',
    );

    test('beririsan di hari yang sama dianggap bentrok', () {
      const b = Jadwal(
        mataKuliahId: 'y',
        hari: 1,
        jamMulai: '09:00',
        jamSelesai: '10:00',
      );
      expect(b.bentrokDengan(a), isTrue);
    });

    test('bersambung tepat tidak bentrok', () {
      const b = Jadwal(
        mataKuliahId: 'y',
        hari: 1,
        jamMulai: '09:40',
        jamSelesai: '11:00',
      );
      expect(b.bentrokDengan(a), isFalse);
    });

    test('hari berbeda tidak bentrok', () {
      const b = Jadwal(
        mataKuliahId: 'y',
        hari: 2,
        jamMulai: '08:00',
        jamSelesai: '09:40',
      );
      expect(b.bentrokDengan(a), isFalse);
    });

    test('tidak bentrok dengan dirinya sendiri saat diedit', () {
      expect(a.bentrokDengan(a), isFalse);
    });
  });

  test('SesiAbsensi.masihBerlaku memeriksa status dan waktu', () {
    final mulai = DateTime(2026, 1, 1, 8);
    final berakhir = DateTime(2026, 1, 1, 8, 15);
    final buka = SesiAbsensi(
      id: 's',
      mataKuliahId: 'x',
      mulai: mulai,
      berakhir: berakhir,
      status: 'buka',
    );
    final tutup = SesiAbsensi(
      id: 's',
      mataKuliahId: 'x',
      mulai: mulai,
      berakhir: berakhir,
      status: 'tutup',
    );

    expect(buka.masihBerlaku(DateTime(2026, 1, 1, 8, 5)), isTrue);
    expect(buka.masihBerlaku(DateTime(2026, 1, 1, 8, 15)), isFalse);
    expect(tutup.masihBerlaku(DateTime(2026, 1, 1, 8, 5)), isFalse);
  });

  test('Tugas.sudahLewatTenggat', () {
    final t = Tugas(
      mataKuliahId: 'x',
      judul: 'T',
      tenggat: DateTime(2026, 1, 10),
    );
    expect(t.sudahLewatTenggat(DateTime(2026, 1, 9)), isFalse);
    expect(t.sudahLewatTenggat(DateTime(2026, 1, 10)), isTrue);
  });

  test('Token absensi 6 karakter tanpa karakter ambigu', () {
    final token = AbsensiRepository.buatToken();
    expect(token, hasLength(6));
    expect(token, isNot(matches(RegExp('[01OI]'))));
  });
}
