-- Data awal kelas TEKOM A 2025, semester ganjil 2026/2027 (jam WITA).
-- Sumber: "Rilis 17 Ags - Jadwal Perkuliahan JTIK TA Ganjil 2026-2027",
-- baris 153-160. Sama dengan lib/data/demo/jadwal_tekom_a_2025.dart.
--
-- Jalankan sekali saja, misalnya di SQL Editor Supabase. File ini tidak ikut
-- `supabase db push` karena berada di luar folder migrations.

with kelas_baru as (
  insert into public.kelas (nama_kelas, angkatan)
  values ('TEKOM A', 2025)
  returning id
),
mk as (
  insert into public.mata_kuliah (kelas_id, nama, kode, sks, dosen)
  select kelas_baru.id, v.nama, v.kode, v.sks, v.dosen
  from kelas_baru,
  (values
    ('Pemrograman Web', '21B01C307', 3, array[
      'Abd. Rahman Patta, S.Kom., M.T., Ph.D.',
      'Mushaf, S. Kom., M.Kom.',
      'Andi Baso Kaswar, S.Pd., M.Kom.']),
    ('Desain Antarmuka Pengguna', '21B01C308', 3, array[
      'Kurnia Prima Putra, S.Kom., M.T.',
      'Ayu Hasnining, S. Kom., M. Kom.']),
    ('Analisis dan Desain Algoritme', '21B01C303', 3, array[
      'Asmaul Husna Nasrullah, S.Kom., M.Kom.',
      'Nurmayanti, S.Pd., M.Pd.']),
    ('Pemrograman Lanjut', '21B01C301', 3, array[
      'M. Syahid Nur Wahid, M.Pd.',
      'Mushaf, S. Kom., M.Kom.']),
    ('Sistem Mikroprosessor + Lab', '21B01C302', 4, array[
      'Dr. Satria Gunawan Zain, S.Pd, M.T.',
      'Figur Muhammad, S.Kom., M.Kom.']),
    ('Matematika Diskrit', '21B01C304', 3, array[
      'Dr. Maya Sari Wahyuni, S.T., M.Kom.',
      'Ayu Hasnining, S. Kom., M. Kom.']),
    ('Kecerdasan Buatan', '21B01C306', 3, array[
      'Muhammad Fajar B, S.Pd., M.Cs.',
      'Abd Salam At Taqwa, S.Pd., M.Kom.']),
    ('Inovasi Teknologi', '21B01C305', 2, array[
      'Ir. Wahyu Hidayat M, S.Pd., M.Pd.',
      'Ninik Rahayu Ashadi, S.Pd., M.Pd.'])
  ) as v (nama, kode, sks, dosen)
  returning id, nama
)
insert into public.jadwal (mata_kuliah_id, hari, jam_mulai, jam_selesai, ruang)
select mk.id, v.hari, v.jam_mulai::time, v.jam_selesai::time, v.ruang
from mk
join (values
  ('Pemrograman Web', 'Senin', '07:30', '10:05', 'Lab Pemrograman'),
  ('Desain Antarmuka Pengguna', 'Selasa', '07:30', '10:05', 'Lab Animasi'),
  ('Analisis dan Desain Algoritme', 'Selasa', '10:05', '12:40', 'AE 109'),
  ('Pemrograman Lanjut', 'Selasa', '14:50', '17:30', 'Lab Pemrograman'),
  ('Sistem Mikroprosessor + Lab', 'Rabu', '07:30', '10:55', 'Lab Embedded'),
  ('Matematika Diskrit', 'Rabu', '14:50', '17:30', 'AE 109'),
  ('Inovasi Teknologi', 'Kamis', '11:00', '12:40', 'AE 109'),
  ('Kecerdasan Buatan', 'Kamis', '14:50', '17:30', 'AE 104')
) as v (nama, hari, jam_mulai, jam_selesai, ruang) on v.nama = mk.nama;

-- Akun: tambahkan email Google setiap admin, dosen, dan mahasiswa. Contoh:
--
-- insert into public.users (nama, username, email_google, peran, kelas_id)
-- select 'Nama Ketua', 'ketua', 'email.ketua@gmail.com', 'admin', id
-- from public.kelas where nama_kelas = 'TEKOM A' and angkatan = 2025;
