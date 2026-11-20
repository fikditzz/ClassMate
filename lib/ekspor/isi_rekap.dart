/// Menyusun [DokumenRekap] dari data aplikasi: daftar hadir, rekap tugas,
/// dan laporan uang kas, semuanya mengikuti format daftar hadir kampus.
library;

import 'package:intl/intl.dart';

import '../core/format.dart';
import '../models/jadwal.dart';
import '../models/kas.dart';
import '../models/mata_kuliah.dart';
import '../models/rekap.dart';
import 'dokumen_rekap.dart';

/// Lebar area cetak A4 lanskap dalam poin.
const lebarHalaman = 770.0;

/// Batas kehadiran minimal untuk boleh ikut ujian.
const batasHadir = 0.75;

final _tglKolom = DateFormat('dd/MM', 'id_ID');
final _tglPanjang = DateFormat('d MMMM y', 'id_ID');
final _tglSedang = DateFormat('dd/MM/yyyy', 'id_ID');

/// Data mata kuliah untuk bagian info dokumen.
class InfoMk {
  const InfoMk({
    required this.mataKuliah,
    required this.kelas,
    this.jadwal = const [],
  });

  final MataKuliah mataKuliah;

  /// Huruf kelas, misalnya "A".
  final String kelas;
  final List<Jadwal> jadwal;

  String get kodeNamaKredit {
    final mk = mataKuliah;
    return [
      if (mk.kode.isNotEmpty) mk.kode,
      mk.nama.toUpperCase(),
      if (mk.sks > 0) '${mk.sks}',
    ].join(' / ');
  }

  /// "SENIN / 07:30-10:00", beberapa jadwal dipisah titik koma.
  String get hariJam => jadwal.isEmpty
      ? '-'
      : [
          for (final j in jadwal)
            '${j.namaHari.toUpperCase()} / ${j.jamMulai}-${j.jamSelesai}',
        ].join('; ');

  String get ruangan {
    final r = {
      for (final j in jadwal)
        if (j.ruang.trim().isNotEmpty) j.ruang,
    };
    return r.isEmpty ? '-' : r.join(', ');
  }

  List<(String, String)> get infoKiri => [
    ('KODE / NAMA MATAKULIAH / KREDIT', kodeNamaKredit),
    ('KELAS', kelas),
  ];

  List<(String, String)> get infoKanan => [
    ('HARI / JAM', hariJam),
    ('RUANGAN', ruangan),
  ];
}

String _persen(double? p) => p == null ? '-' : '${(p * 100).round()}%';

/// Daftar hadir per mata kuliah (15 mahasiswa per halaman, kolom 1–7,
/// UTS, 8–14, UAS) ditambah lembar rekapitulasi.
DokumenRekap dokumenDaftarHadir(
  RekapAbsenMk r,
  InfoMk info, {
  KopDokumen kop = const KopDokumen(),
  DateTime? dicetak,
}) {
  final waktu = dicetak ?? DateTime.now();
  const kiri = [26.0, 69.0, 160.0];
  final sisa = lebarHalaman - kiri.fold(0.0, (a, b) => a + b);
  final kolom = RekapAbsenMk.labelKolom.length;
  final lebar = [...kiri, for (var i = 0; i < kolom; i++) sisa / kolom];

  final daftar = TabelRekap(
    namaLembar: 'Daftar Hadir',
    lebar: lebar,
    jumlahBarisKepala: 3,
    kepala: [
      const SelKepala(0, 0, 'NO.', rentangBaris: 3),
      const SelKepala(0, 1, 'STAMBUK', rentangBaris: 3),
      const SelKepala(0, 2, 'TANGGAL', rata: Rata.kiri),
      const SelKepala(1, 2, 'TANDA TANGAN DOSEN', rata: Rata.kiri),
      const SelKepala(2, 2, 'NAMA MAHASISWA', rata: Rata.kiri),
      for (var k = 0; k < kolom; k++) ...[
        SelKepala(0, 3 + k, switch (r.pertemuanKolom(k)) {
          final p? => _tglKolom.format(p.tanggal),
          null => '',
        }, tebal: false),
        SelKepala(1, 3 + k, '', tebal: false),
        SelKepala(2, 3 + k, RekapAbsenMk.labelKolom[k]),
      ],
    ],
    isi: [
      for (final (i, m) in r.mahasiswa.indexed)
        [
          i + 1,
          m.stambuk,
          m.nama.toUpperCase(),
          for (var k = 0; k < kolom; k++) r.sel(k, m.id).teks,
        ],
    ],
    rata: [
      Rata.tengah,
      Rata.tengah,
      Rata.kiri,
      for (var k = 0; k < kolom; k++) Rata.tengah,
    ],
    barisPerHalaman: 15,
    catatanTiapHalaman: true,
    catatan: [
      'Catatan : Diharapkan dosen tidak memasukkan mahasiswa pada daftar '
          'hadir sebelum mahasiswa tersebut melapor ke administrasi akademik.',
      'Keterangan : H = Hadir, A = Tidak hadir, - = Ujian (UTS/UAS), '
          'kosong = pertemuan belum berlangsung.'
          '${r.pertemuanLebih > 0 ? ' Ada ${r.pertemuanLebih} pertemuan '
                    'tambahan yang dihitung di lembar rekapitulasi.' : ''}',
    ],
  );

  final rekap = TabelRekap(
    namaLembar: 'Rekapitulasi',
    judul: 'REKAPITULASI KEHADIRAN MAHASISWA',
    lebar: const [26, 69, 215, 70, 70, 70, 70, 180],
    jumlahBarisKepala: 1,
    kepala: const [
      SelKepala(0, 0, 'NO.'),
      SelKepala(0, 1, 'STAMBUK'),
      SelKepala(0, 2, 'NAMA MAHASISWA', rata: Rata.kiri),
      SelKepala(0, 3, 'HADIR'),
      SelKepala(0, 4, 'TIDAK HADIR'),
      SelKepala(0, 5, 'PERTEMUAN'),
      SelKepala(0, 6, 'PERSENTASE'),
      SelKepala(0, 7, 'KETERANGAN'),
    ],
    isi: [
      for (final (i, m) in r.mahasiswa.indexed)
        [
          i + 1,
          m.stambuk,
          m.nama.toUpperCase(),
          r.jumlahHadir(m.id),
          r.pertemuan.length - r.jumlahHadir(m.id),
          r.pertemuan.length,
          _persen(r.persen(m.id)),
          switch (r.persen(m.id)) {
            null => '-',
            final p when p >= batasHadir => 'Memenuhi',
            _ => 'Di bawah ${(batasHadir * 100).round()}%',
          },
        ],
    ],
    rata: const [
      Rata.tengah, Rata.tengah, Rata.kiri, Rata.tengah, //
      Rata.tengah, Rata.tengah, Rata.tengah, Rata.tengah,
    ],
    catatan: [
      'Rata-rata kehadiran kelas: ${_persen(r.rataRata)} dari '
          '${r.pertemuan.length} pertemuan. Batas minimal kehadiran '
          '${(batasHadir * 100).round()}%.',
    ],
  );

  return DokumenRekap(
    judul: 'DAFTAR HADIR MAHASISWA DAN DOSEN',
    subjudul: KopDokumen.semester(waktu),
    namaBerkas: namaBerkasAman(
      'Daftar_Hadir_${info.mataKuliah.nama}_Kelas_${info.kelas}',
    ),
    kop: kop,
    infoKiri: info.infoKiri,
    infoKanan: info.infoKanan,
    dosen: info.mataKuliah.dosen,
    tabel: [daftar, rekap],
    dicetak: waktu,
  );
}

/// Rekap pengumpulan tugas per mata kuliah.
DokumenRekap dokumenRekapTugas(
  RekapTugasMk r,
  InfoMk info, {
  KopDokumen kop = const KopDokumen(),
  DateTime? dicetak,
}) {
  final waktu = dicetak ?? DateTime.now();
  const kiri = [26.0, 69.0, 160.0];
  const lebarJumlah = 60.0;
  final n = r.tugas.isEmpty ? 1 : r.tugas.length;
  final ruang = lebarHalaman - 255 - lebarJumlah;
  final lebarSel = (ruang / n).clamp(0.0, 64.0);
  // Sisa ruang diberikan ke kolom nama agar tabel tetap selebar halaman.
  final lebar = [
    kiri[0],
    kiri[1],
    kiri[2] + ruang - lebarSel * n,
    for (var i = 0; i < n; i++) lebarSel,
    lebarJumlah,
  ];

  final tabel = TabelRekap(
    namaLembar: 'Rekap Tugas',
    lebar: lebar,
    jumlahBarisKepala: 2,
    kepala: [
      const SelKepala(0, 0, 'NO.', rentangBaris: 2),
      const SelKepala(0, 1, 'STAMBUK', rentangBaris: 2),
      const SelKepala(0, 2, 'TENGGAT', rata: Rata.kiri),
      const SelKepala(1, 2, 'NAMA MAHASISWA', rata: Rata.kiri),
      for (var k = 0; k < n; k++) ...[
        SelKepala(
          0,
          3 + k,
          r.tugas.isEmpty ? '' : _tglKolom.format(r.tugas[k].tenggat),
          tebal: false,
        ),
        SelKepala(1, 3 + k, r.tugas.isEmpty ? '-' : 'T${k + 1}'),
      ],
      SelKepala(0, 3 + n, 'JUMLAH', rentangBaris: 2),
    ],
    isi: [
      for (final (i, m) in r.mahasiswa.indexed)
        [
          i + 1,
          m.stambuk,
          m.nama.toUpperCase(),
          if (r.tugas.isEmpty)
            ''
          else
            for (final t in r.tugas)
              r.terkumpul(t.id, m.id) ? 'Sudah' : 'Belum',
          '${r.jumlahTerkumpul(m.id)}/${r.tugas.length}',
        ],
    ],
    rata: [
      Rata.tengah, Rata.tengah, Rata.kiri, //
      for (var k = 0; k < n; k++) Rata.tengah,
      Rata.tengah,
    ],
    barisPerHalaman: 15,
    catatanTiapHalaman: true,
    catatan: [
      if (r.tugas.isEmpty)
        'Belum ada tugas untuk mata kuliah ini.'
      else
        'Keterangan : ${[for (final (i, t) in r.tugas.indexed) 'T${i + 1} = ${t.judul} (tenggat ${_tglSedang.format(t.tenggat)}, ${r.pengumpulTugas(t.id)}/${r.mahasiswa.length} terkumpul)'].join('; ')}.',
    ],
  );

  return DokumenRekap(
    judul: 'REKAP PENGUMPULAN TUGAS MAHASISWA',
    subjudul: KopDokumen.semester(waktu),
    namaBerkas: namaBerkasAman(
      'Rekap_Tugas_${info.mataKuliah.nama}_Kelas_${info.kelas}',
    ),
    kop: kop,
    infoKiri: info.infoKiri,
    infoKanan: info.infoKanan,
    dosen: info.mataKuliah.dosen,
    tabel: [tabel],
    dicetak: waktu,
  );
}

/// Laporan uang kas: buku kas (urut tanggal, dengan saldo berjalan) dan
/// status iuran tiap anggota.
DokumenRekap dokumenKas({
  required List<TransaksiKas> riwayat,
  required List<StatusIuran> status,
  required RingkasanKas ringkasan,
  required String namaKelas,
  KopDokumen kop = const KopDokumen(),
  DateTime? dicetak,
}) {
  final waktu = dicetak ?? DateTime.now();
  final urut = [...riwayat]..sort((a, b) => a.tanggal.compareTo(b.tanggal));
  var saldo = 0, masuk = 0, keluar = 0;
  final isiBuku = <List<Object>>[];
  for (final (i, t) in urut.indexed) {
    saldo += t.nilai;
    if (t.jenis.masuk) {
      masuk += t.jumlah;
    } else {
      keluar += t.jumlah;
    }
    final uraian = t.jenis == JenisKas.iuran && t.namaAnggota != null
        ? '${t.judul} - ${t.namaAnggota}'
        : t.judul;
    isiBuku.add([
      i + 1,
      _tglSedang.format(t.tanggal),
      uraian,
      t.jenis.label,
      t.jenis.masuk ? t.jumlah : '',
      t.jenis.masuk ? '' : t.jumlah,
      saldo,
    ]);
  }
  isiBuku.add(['', '', 'JUMLAH', '', masuk, keluar, saldo]);

  final buku = TabelRekap(
    namaLembar: 'Buku Kas',
    judul: 'LAPORAN UANG KAS KELAS',
    lebar: const [26, 70, 284, 70, 100, 100, 120],
    jumlahBarisKepala: 1,
    kepala: const [
      SelKepala(0, 0, 'NO.'),
      SelKepala(0, 1, 'TANGGAL'),
      SelKepala(0, 2, 'URAIAN', rata: Rata.kiri),
      SelKepala(0, 3, 'JENIS'),
      SelKepala(0, 4, 'MASUK'),
      SelKepala(0, 5, 'KELUAR'),
      SelKepala(0, 6, 'SALDO'),
    ],
    isi: isiBuku,
    rata: const [
      Rata.tengah, Rata.tengah, Rata.kiri, Rata.tengah, //
      Rata.kanan, Rata.kanan, Rata.kanan,
    ],
    kolomRupiah: const {4, 5, 6},
    barisTebal: {isiBuku.length - 1},
    catatan: [
      'Saldo akhir ${formatRupiah(ringkasan.saldo)}. '
          'Bulan ${formatBulanTahun(waktu)}: masuk '
          '${formatRupiah(ringkasan.masukBulanIni)}, keluar '
          '${formatRupiah(ringkasan.keluarBulanIni)}.',
    ],
  );

  final aturan = ringkasan.aturan;
  final tabel = [buku];
  if (status.isNotEmpty) {
    final s = [...status]..sort((a, b) => a.nama.compareTo(b.nama));
    tabel.add(
      TabelRekap(
        namaLembar: 'Status Iuran',
        judul: 'STATUS IURAN ANGGOTA KELAS',
        lebar: const [26, 230, 80, 110, 90, 110, 124],
        jumlahBarisKepala: 1,
        kepala: const [
          SelKepala(0, 0, 'NO.'),
          SelKepala(0, 1, 'NAMA ANGGOTA', rata: Rata.kiri),
          SelKepala(0, 2, 'KALI BAYAR'),
          SelKepala(0, 3, 'TOTAL BAYAR'),
          SelKepala(0, 4, 'PEKAN LUNAS'),
          SelKepala(0, 5, 'TUNGGAKAN'),
          SelKepala(0, 6, 'TERAKHIR BAYAR'),
        ],
        isi: [
          for (final (i, x) in s.indexed)
            [
              i + 1,
              x.nama.toUpperCase(),
              x.kaliBayar,
              x.totalBayar,
              aturan == null
                  ? '${x.pekanLunas(aturan)}'
                  : '${x.pekanLunas(aturan)}/${aturan.pekanBerjalan(waktu)}',
              x.tunggakan(aturan, waktu),
              x.terakhir == null ? '-' : _tglSedang.format(x.terakhir!),
            ],
        ],
        rata: const [
          Rata.tengah, Rata.kiri, Rata.tengah, Rata.kanan, //
          Rata.tengah, Rata.kanan, Rata.tengah,
        ],
        kolomRupiah: const {3, 5},
        catatan: [
          if (aturan == null)
            'Iuran mingguan belum diatur.'
          else
            'Iuran ${formatRupiah(aturan.nominal)} per pekan sejak '
                '${_tglPanjang.format(aturan.mulai)} '
                '(${aturan.pekanBerjalan(waktu)} pekan).',
        ],
      ),
    );
  }

  return DokumenRekap(
    judul: 'LAPORAN UANG KAS KELAS',
    subjudul: KopDokumen.semester(waktu),
    namaBerkas: namaBerkasAman('Laporan_Kas_$namaKelas'),
    kop: kop,
    infoKiri: [
      ('KELAS', namaKelas),
      ('PER TANGGAL', _tglPanjang.format(waktu).toUpperCase()),
    ],
    infoKanan: [
      ('SALDO KAS', formatRupiah(ringkasan.saldo)),
      (
        'IURAN MINGGUAN',
        aturan == null ? '-' : '${formatRupiah(aturan.nominal)} / PEKAN',
      ),
    ],
    tabel: tabel,
    dicetak: waktu,
  );
}
