import 'package:classmate/data/demo/demo_backend.dart';
import 'package:classmate/data/supabase/pemetaan.dart';
import 'package:classmate/models/akun.dart';
import 'package:classmate/models/jadwal.dart';
import 'package:classmate/models/mata_kuliah.dart';
import 'package:classmate/models/pengguna.dart';
import 'package:classmate/models/perubahan_jadwal.dart';
import 'package:classmate/core/errors.dart';
import 'package:flutter_test/flutter_test.dart';

const _senin = Jadwal(
  id: '1',
  mataKuliahId: 'mk1',
  hari: 1,
  jamMulai: '07:30',
  jamSelesai: '10:05',
  ruang: 'Lab',
);
const _selasa = Jadwal(
  id: '2',
  mataKuliahId: 'mk2',
  hari: 2,
  jamMulai: '13:00',
  jamSelesai: '15:30',
  ruang: 'AE 109',
);

// Senin 16 November 2026 dan minggu berikutnya.
final _s1 = DateTime(2026, 11, 16);
final _s2 = DateTime(2026, 11, 23);

void main() {
  group('pertemuanPada', () {
    test('tanpa perubahan: jadwal tetap di hari itu', () {
      final p = pertemuanPada(_s1, const [_senin, _selasa], const []);
      expect(p, hasLength(1));
      expect(p.single.status, StatusPertemuan.biasa);
      expect(p.single.berlangsung, isTrue);
    });

    test('libur hanya untuk tanggal itu, minggu depan tetap masuk', () {
      final libur = PerubahanJadwal(
        id: '9',
        jenis: JenisPerubahan.libur,
        mataKuliahId: 'mk1',
        jadwalId: '1',
        tanggalAsal: _s1,
      );
      final minggu1 = pertemuanPada(_s1, const [_senin], [libur]);
      expect(minggu1.single.status, StatusPertemuan.libur);
      expect(minggu1.single.berlangsung, isFalse);
      final minggu2 = pertemuanPada(_s2, const [_senin], [libur]);
      expect(minggu2.single.status, StatusPertemuan.biasa);
    });

    test('pindah: asal ditandai dipindah, tujuan muncul sebagai pengganti', () {
      final kamis = DateTime(2026, 11, 19);
      final pindah = PerubahanJadwal(
        id: '10',
        jenis: JenisPerubahan.pindah,
        mataKuliahId: 'mk1',
        jadwalId: '1',
        tanggalAsal: _s1,
        tanggal: kamis,
        jamMulai: '10:00',
        jamSelesai: '12:00',
      );
      final asal = pertemuanPada(_s1, const [_senin], [pindah]);
      expect(asal.single.status, StatusPertemuan.dipindahKeluar);
      final tujuan = pertemuanPada(kamis, const [_senin], [pindah]);
      expect(tujuan.single.status, StatusPertemuan.pengganti);
      expect(tujuan.single.jadwal.hari, DateTime.thursday);
      expect(tujuan.single.jadwal.jamMulai, '10:00');
      // Ruang tidak diisi: ikut ruang jadwal asal.
      expect(tujuan.single.jadwal.ruang, 'Lab');
      expect(tujuan.single.asal, _senin);
    });

    test('pindah di hari yang sama ke jam lain', () {
      final pindah = PerubahanJadwal(
        id: '11',
        jenis: JenisPerubahan.pindah,
        mataKuliahId: 'mk1',
        jadwalId: '1',
        tanggalAsal: _s1,
        tanggal: _s1,
        jamMulai: '15:00',
        jamSelesai: '17:00',
        ruang: 'AE 101',
      );
      final p = pertemuanPada(_s1, const [_senin], [pindah]);
      expect(p.map((x) => x.status), [
        StatusPertemuan.dipindahKeluar,
        StatusPertemuan.pengganti,
      ]);
      expect(p.last.jadwal.ruang, 'AE 101');
    });

    test('kuliah tambahan muncul di tanggalnya saja, terurut jam', () {
      final tambahan = PerubahanJadwal(
        id: '12',
        jenis: JenisPerubahan.tambahan,
        mataKuliahId: 'mk3',
        tanggal: _s1,
        jamMulai: '06:30',
        jamSelesai: '07:20',
      );
      final p = pertemuanPada(_s1, const [_senin], [tambahan]);
      expect(p.first.status, StatusPertemuan.tambahan);
      expect(p.last.status, StatusPertemuan.biasa);
      expect(pertemuanPada(_s2, const [_senin], [tambahan]), hasLength(1));
    });

    test('pindahan dari jadwal yang sudah dihapus tidak tampil', () {
      final pindah = PerubahanJadwal(
        id: '13',
        jenis: JenisPerubahan.pindah,
        mataKuliahId: 'mk1',
        jadwalId: 'hilang',
        tanggalAsal: _s1,
        tanggal: _s1,
        jamMulai: '15:00',
        jamSelesai: '16:00',
      );
      expect(pertemuanPada(_s1, const [], [pindah]), isEmpty);
    });
  });

  group('bentrokPada', () {
    test('mengabaikan pertemuan yang sedang dipindah dan yang libur', () {
      const baru = Jadwal(
        mataKuliahId: 'mk1',
        hari: 1,
        jamMulai: '08:00',
        jamSelesai: '09:00',
      );
      expect(bentrokPada(_s1, baru, const [_senin], const []), hasLength(1));
      expect(
        bentrokPada(_s1, baru, const [_senin], const [], abaikanJadwalId: '1'),
        isEmpty,
      );
      final libur = PerubahanJadwal(
        id: '1',
        jenis: JenisPerubahan.libur,
        mataKuliahId: 'mk1',
        jadwalId: '1',
        tanggalAsal: _s1,
      );
      expect(bentrokPada(_s1, baru, const [_senin], [libur]), isEmpty);
    });
  });

  group('pemetaan Supabase', () {
    test('perubahan bolak-balik', () {
      final p = perubahanDari({
        'id': 5,
        'jenis': 'pindah',
        'mata_kuliah_id': 3,
        'jadwal_id': 7,
        'tanggal_asal': '2026-11-16',
        'tanggal': '2026-11-19',
        'jam_mulai': '10:00:00',
        'jam_selesai': '12:00:00',
        'ruang': null,
        'keterangan': 'Dosen dinas luar',
      });
      expect(p.jenis, JenisPerubahan.pindah);
      expect(p.tanggalAsal, DateTime(2026, 11, 16));
      expect(p.jamMulai, '10:00');
      expect(perubahanKeBaris(p), {
        'jenis': 'pindah',
        'mata_kuliah_id': 3,
        'jadwal_id': 7,
        'tanggal_asal': '2026-11-16',
        'tanggal': '2026-11-19',
        'jam_mulai': '10:00',
        'jam_selesai': '12:00',
        'ruang': null,
        'keterangan': 'Dosen dinas luar',
      });
    });

    test('libur tidak mengirim tanggal dan jam tujuan', () {
      final baris = perubahanKeBaris(
        PerubahanJadwal(
          jenis: JenisPerubahan.libur,
          mataKuliahId: '3',
          jadwalId: '7',
          tanggalAsal: DateTime(2026, 11, 16),
          tanggal: DateTime(2026, 11, 19),
          jamMulai: '10:00',
          jamSelesai: '12:00',
          ruang: 'AE',
        ),
      );
      expect(baris['tanggal'], isNull);
      expect(baris['jam_mulai'], isNull);
      expect(baris['ruang'], isNull);
    });

    test('akun dan mata kuliah', () {
      final a = akunDari({
        'id': 11,
        'nama': 'Admin Contoh',
        'username': 'admin.contoh',
        'email': 'admin@contoh.test',
        'peran': 'admin',
        'punya_login': true,
        'login_terakhir': null,
      });
      expect(a.id, '11');
      expect(a.labelPeran, 'Admin Kelas');
      expect(a.punyaLogin, isTrue);
      expect(
        mataKuliahKeBaris(
          const MataKuliah(
            id: '1',
            nama: ' Basis Data ',
            kode: '',
            sks: 3,
            dosen: ['A', ' ', 'B '],
          ),
        ),
        {
          'nama': 'Basis Data',
          'kode': null,
          'sks': 3,
          'dosen': ['A', 'B'],
        },
      );
    });
  });

  group('akun demo', () {
    test(
      'anggota tidak boleh mengelola akun; admin tidak bisa hapus diri',
      () async {
        final backend = DemoBackend();
        final anggota = await backend.auth.masukSebagai(admin: false);
        await expectLater(
          backend.buatRepositori(anggota).akun.daftarAkun(),
          throwsA(isA<ClassMateException>()),
        );

        final admin = await backend.auth.masukSebagai(admin: true);
        final repo = backend.buatRepositori(admin).akun;
        await repo.buatAkun(
          const Akun(
            nama: 'Amir',
            username: 'amir',
            email: 'Amir@Contoh.test',
            peran: 'mahasiswa',
          ),
          'rahasia123',
        );
        final daftar = await repo.daftarAkun();
        expect(daftar.map((a) => a.email), contains('amir@contoh.test'));
        await expectLater(
          repo.buatAkun(
            const Akun(
              nama: 'X',
              username: 'x',
              email: 'amir@contoh.test',
              peran: 'mahasiswa',
            ),
            'rahasia123',
          ),
          throwsA(isA<ClassMateException>()),
        );
        await expectLater(
          repo.aturPassword('demo-anggota', 'pendek'),
          throwsA(isA<ClassMateException>()),
        );
        await expectLater(
          repo.hapusAkun(admin.uid),
          throwsA(isA<ClassMateException>()),
        );
        expect(admin.bolehKelolaAkun, isTrue);
        expect(
          Pengguna.dariData(
            uid: '1',
            email: 'd@k.id',
            data: {'peran': 'dosen'},
          ).bolehKelolaAkun,
          isFalse,
        );
      },
    );
  });
}
