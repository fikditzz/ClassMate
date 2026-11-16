// Data sementara: jadwal kelas TEKOM A 2025, semester ganjil 2026/2027.
// Sumber: "Rilis 17 Ags - Jadwal Perkuliahan JTIK TA Ganjil 2026-2027",
// baris 153–160. Jam dalam WITA.
//
// Dipakai oleh DemoBackend. Untuk Firebase, isi koleksi `mata_kuliah` dan
// `jadwal` dengan data yang sama (lihat README).
import '../../models/jadwal.dart';
import '../../models/mata_kuliah.dart';

const kelasTekomA2025 = 'TEKOM A 2025';

const mataKuliahTekomA2025 = [
  MataKuliah(
    id: 'pweb',
    nama: 'Pemrograman Web',
    kelasId: kelasTekomA2025,
    kode: '21B01C307',
    sks: 3,
    dosen: [
      'Abd. Rahman Patta, S.Kom., M.T., Ph.D.',
      'Mushaf, S. Kom., M.Kom.',
      'Andi Baso Kaswar, S.Pd., M.Kom.',
    ],
  ),
  MataKuliah(
    id: 'dap',
    nama: 'Desain Antarmuka Pengguna',
    kelasId: kelasTekomA2025,
    kode: '21B01C308',
    sks: 3,
    dosen: [
      'Kurnia Prima Putra, S.Kom., M.T.',
      'Ayu Hasnining, S. Kom., M. Kom.',
    ],
  ),
  MataKuliah(
    id: 'ada',
    nama: 'Analisis dan Desain Algoritme',
    kelasId: kelasTekomA2025,
    kode: '21B01C303',
    sks: 3,
    dosen: [
      'Asmaul Husna Nasrullah, S.Kom., M.Kom.',
      'Nurmayanti, S.Pd., M.Pd.',
    ],
  ),
  MataKuliah(
    id: 'plj',
    nama: 'Pemrograman Lanjut',
    kelasId: kelasTekomA2025,
    kode: '21B01C301',
    sks: 3,
    dosen: ['M. Syahid Nur Wahid, M.Pd.', 'Mushaf, S. Kom., M.Kom.'],
  ),
  MataKuliah(
    id: 'smp',
    nama: 'Sistem Mikroprosessor + Lab',
    kelasId: kelasTekomA2025,
    kode: '21B01C302',
    sks: 4,
    dosen: [
      'Dr. Satria Gunawan Zain, S.Pd, M.T.',
      'Figur Muhammad, S.Kom., M.Kom.',
    ],
  ),
  MataKuliah(
    id: 'mdk',
    nama: 'Matematika Diskrit',
    kelasId: kelasTekomA2025,
    kode: '21B01C304',
    sks: 3,
    dosen: [
      'Dr. Maya Sari Wahyuni, S.T., M.Kom.',
      'Ayu Hasnining, S. Kom., M. Kom.',
    ],
  ),
  MataKuliah(
    id: 'kb',
    nama: 'Kecerdasan Buatan',
    kelasId: kelasTekomA2025,
    kode: '21B01C306',
    sks: 3,
    dosen: [
      'Muhammad Fajar B, S.Pd., M.Cs.',
      'Abd Salam At Taqwa, S.Pd., M.Kom.',
    ],
  ),
  MataKuliah(
    id: 'inotek',
    nama: 'Inovasi Teknologi',
    kelasId: kelasTekomA2025,
    kode: '21B01C305',
    sks: 2,
    dosen: [
      'Ir. Wahyu Hidayat M, S.Pd., M.Pd.',
      'Ninik Rahayu Ashadi, S.Pd., M.Pd.',
    ],
  ),
];

/// hari: 1 = Senin ... 7 = Minggu.
const jadwalTekomA2025 = [
  Jadwal(
    id: 'j153',
    mataKuliahId: 'pweb',
    hari: 1,
    jamMulai: '07:30',
    jamSelesai: '10:05',
    ruang: 'Lab Pemrograman',
  ),
  Jadwal(
    id: 'j154',
    mataKuliahId: 'dap',
    hari: 2,
    jamMulai: '07:30',
    jamSelesai: '10:05',
    ruang: 'Lab Animasi',
  ),
  Jadwal(
    id: 'j155',
    mataKuliahId: 'ada',
    hari: 2,
    jamMulai: '10:05',
    jamSelesai: '12:40',
    ruang: 'AE 109',
  ),
  Jadwal(
    id: 'j156',
    mataKuliahId: 'plj',
    hari: 2,
    jamMulai: '14:50',
    jamSelesai: '17:30',
    ruang: 'Lab Pemrograman',
  ),
  Jadwal(
    id: 'j157',
    mataKuliahId: 'smp',
    hari: 3,
    jamMulai: '07:30',
    jamSelesai: '10:55',
    ruang: 'Lab Embedded',
  ),
  Jadwal(
    id: 'j158',
    mataKuliahId: 'mdk',
    hari: 3,
    jamMulai: '14:50',
    jamSelesai: '17:30',
    ruang: 'AE 109',
  ),
  Jadwal(
    id: 'j160',
    mataKuliahId: 'inotek',
    hari: 4,
    jamMulai: '11:00',
    jamSelesai: '12:40',
    ruang: 'AE 109',
  ),
  Jadwal(
    id: 'j159',
    mataKuliahId: 'kb',
    hari: 4,
    jamMulai: '14:50',
    jamSelesai: '17:30',
    ruang: 'AE 104',
  ),
];
