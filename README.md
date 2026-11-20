# ClassMate

Aplikasi mobile Flutter untuk mengelola kebutuhan satu kelas: absensi dengan token,
pengumpulan tugas, dan jadwal kuliah. Backend memakai **Supabase paket Free**
(Auth, Postgres dengan RLS, Realtime), tanpa server sendiri. Lihat PRD v0.4.

## Status basis dasar

| Fitur | Status |
|---|---|
| Login email + password, cek email terdaftar (AUTH) | ✅ (Google menyusul, perlu Client ID) |
| Dashboard: jadwal hari ini, sesi aktif, tenggat dekat (DSB) | ✅ |
| Absensi: buat sesi + token, absen, tutup sesi, rekap per sesi (ABS) | ✅ (rekap per anggota belum) |
| Tugas: buat, ubah, hapus tugas, status pengumpulan (TGS) | ⚠️ unggah berkas belum (`PenyimpananBerkas` baru kontrak) |
| Jadwal: tampilan harian & penuh, jadwal tetap, peringatan bentrok (JDW) | ✅ |
| Perubahan per pertemuan: libur, pindah hari/jam, kuliah tambahan | ✅ |
| Kelola akun (admin): tambah, ubah peran, atur password, hapus | ✅ Edge Function `kelola-akun` |
| Kelola mata kuliah (admin/dosen) | ✅ |
| Ganti password sendiri (perlu password lama) | ✅ |
| Notifikasi (NTF) | ⏳ belum (tabel `device_token` sudah ada) |
| Uang Kas (KAS) | ⏳ belum (tabel dan RLS sudah disiapkan) |
| Keamanan database (RLS) | ✅ `supabase/migrations` |

## Mode demo

Selama URL atau publishable key di `lib/supabase_options.dart` kosong, aplikasi
otomatis berjalan dalam **mode demo** dengan data contoh di memori.
Di layar login pilih masuk sebagai Anggota atau Admin. Token sesi contoh: `KLS123`.

```bash
flutter run
```

Mode demo juga bisa dipaksa walau Supabase sudah dikonfigurasi:

```bash
flutter run --dart-define=DEMO=true
```

## Supabase

Proyek: `ClassMate` (`smifusynzjyqpdhmmooz`, region ap-southeast-2). URL dan
publishable key ada di `lib/supabase_options.dart`. Publishable key memang boleh ada
di aplikasi karena semua akses dibatasi RLS. **Jangan** menaruh secret key atau
`service_role` key di kode aplikasi.

### Skema dan aturan keamanan

Skema awal (10 tabel) dibuat langsung di dashboard. Perubahan berikutnya disimpan
sebagai migrasi di `supabase/migrations/`:

- `20261115160000_keamanan_dan_penyesuaian.sql`: menyalakan RLS di semua tabel,
  menutup akses tanpa login, memindah token absen ke tabel `sesi_token` (hanya bisa
  dibaca admin/dosen), menambah kolom `kode`, `sks`, `dosen` di `mata_kuliah`, serta
  fungsi `absen()`, `buat_sesi()`, dan `pengguna_saya()`.
- `20261115161000_rapikan_index_dan_policy.sql`: menghapus index ganda dan memecah
  policy sesuai saran `supabase db advisors`.
- `20261116090000_kelola_akun_dan_perubahan_jadwal.sql`: tabel `perubahan_jadwal`
  (libur, pindah, tambahan per pertemuan), fungsi `daftar_akun()` untuk admin, email
  `users` wajib huruf kecil, dan `kelas_id` mata kuliah baru otomatis ikut kelas
  pembuatnya.

Akun login dikelola Edge Function `supabase/functions/kelola-akun` (aksi `buat`,
`ubah`, `atur_password`, `hapus`). Fungsi ini memakai kunci rahasia yang hanya ada di
server Supabase, memeriksa bahwa pemanggil adalah admin, dan menolak admin menghapus
atau menurunkan peran dirinya sendiri. Memasang ulang setelah diubah:

```bash
npx supabase functions deploy kelola-akun --use-api
```

Ringkasan aturan:

| Peran (`users.peran`) | Hak |
|---|---|
| `mahasiswa` | melihat jadwal, tugas, sesi; absen lewat `absen()`; mengumpulkan sebelum tenggat; hanya melihat data kehadiran/pengumpulan sendiri |
| `dosen` | seperti admin untuk mata kuliah, jadwal (termasuk libur/pindah/tambahan), sesi, tugas, dan rekap |
| `admin` | semua hak dosen, ditambah mengelola akun (termasuk mengatur password tanpa password lama), kelas, dan uang kas |

Email Google yang tidak ada di tabel `users`, atau belum terverifikasi, tidak bisa
melihat data apa pun. Tanggal dan jam sesi absen dibaca sebagai **WITA**.

Menerapkan migrasi baru (perlu `npx supabase login` dan `npx supabase link` sekali
di folder ini):

```bash
npx supabase db push --remote
```

Memeriksa saran keamanan dan performa:

```bash
npx supabase db advisors --remote --type all
```

### Login email dan password (dipakai sekarang)

Akun dibuat admin, bukan didaftarkan sendiri oleh pengguna:

1. Di dashboard Supabase buka **Authentication → Sign In / Providers**:
   - provider **Email** tetap aktif;
   - matikan **Allow new users to sign up**, agar orang tidak bisa membuat akun sendiri.
2. Buka **Authentication → Users → Add user → Create new user**, isi email dan
   password, lalu centang **Auto Confirm User**.
3. Pastikan email yang sama ada di tabel `users` (lihat "Data awal"). Akun Auth
   tanpa baris di `users` tetap ditolak aplikasi.

Password hanya tersimpan di Supabase Auth, tidak di tabel `users` atau di aplikasi.

### Login Google (nanti)

Tombol "Masuk dengan Google" muncul di layar login setelah `googleWebClientId` diisi.
Saat beralih ke Google, nyalakan lagi **Allow new users to sign up**, karena login
Google pertama kali dihitung sebagai pendaftaran. RLS tetap menolak email yang tidak
ada di tabel `users`.

1. Di [Google Cloud Console](https://console.cloud.google.com/apis/credentials) buat
   OAuth Client ID:
   - **Web application**: ID ini diisi ke `googleWebClientId`.
   - **Android**: package `com.classmate.classmate` dan SHA-1
     debug dari `cd android && ./gradlew signingReport`.
   - **iOS** (bila membangun untuk iOS): diisi ke `googleIosClientId`.
2. Di dashboard Supabase buka **Authentication → Sign In / Providers → Google**,
   aktifkan, lalu isi **Client IDs** dengan Web Client ID (dan iOS Client ID, dipisah
   koma). Bila login di iOS gagal karena *nonce*, aktifkan **Skip nonce check**.
3. Isi `googleWebClientId` di `lib/supabase_options.dart`.

### Data awal

1. Jalankan `supabase/data_awal_tekom_a_2025.sql` sekali di **SQL Editor** untuk
   mengisi kelas TEKOM A 2025, 8 mata kuliah, dan jadwalnya.
2. Tambahkan akun (email Google huruf kecil) ke tabel `users`, misalnya:

   ```sql
   insert into public.users (nama, username, email_google, peran, kelas_id)
   select 'Nama Ketua', 'ketua', 'email.ketua@gmail.com', 'admin', id
   from public.kelas where nama_kelas = 'TEKOM A' and angkatan = 2025;
   ```

## Struktur kode

```
lib/
  main.dart                 memilih backend Supabase atau demo
  supabase_options.dart     URL, publishable key, Google Client ID
  app.dart                  MaterialApp + AuthGate
  core/                     tema, format tanggal, error, AppScope
  models/                   Pengguna (Admin/Dosen/Anggota), Jadwal, SesiAbsensi, Kehadiran, Tugas, Pengumpulan, MataKuliah
  repositories/             kontrak abstract: Auth, Absensi, Tugas, Jadwal, PenyimpananBerkas
  data/supabase/            implementasi Supabase + pemetaan baris tabel ke model
  data/demo/                implementasi demo di memori (dipakai juga oleh tes)
  data/firebase/            implementasi Firebase lama (tidak dipakai lagi)
  pages/                    LoginPage, HomeShell, DashboardPage, AbsensiPage, TugasPage, JadwalPage
  widgets/                  komponen umum (keadaan kosong, label status, lembar bawah)
supabase/
  migrations/               perubahan skema dan RLS
  data_awal_tekom_a_2025.sql
```

Halaman hanya bergantung pada repository abstract, sehingga backend bisa diganti
(misalnya ke versi demo untuk pengujian) tanpa mengubah halaman.

`lib/data/firebase/`, `lib/firebase_options.dart`, `firestore.rules`, dan paket
Firebase di `pubspec.yaml` masih ada dari versi sebelumnya, tetapi tidak dipakai lagi.

## Pengujian

```bash
flutter test
```

`test/supabase_pemetaan_test.dart` menguji konversi baris Supabase, termasuk jam WITA.

## Langkah berikutnya

- `PenyimpananBerkas` (Supabase Storage atau Google Drive) dan tombol unggah di TugasPage.
- Daftar anggota yang **belum** mengumpulkan dan rekap kehadiran per anggota.
- Membatasi data per kelas lewat `kelas_id` bila satu proyek dipakai beberapa kelas.
- Notifikasi dengan `flutter_local_notifications` (tabel `device_token` sudah ada).

## Data contoh: TEKOM A 2025

Mode demo memakai jadwal asli kelas TEKOM A 2025 (semester ganjil 2026/2027,
jam WITA) dari dokumen rilis jadwal JTIK 17 Agustus. Datanya ada di
`lib/data/demo/jadwal_tekom_a_2025.dart` dan `supabase/data_awal_tekom_a_2025.sql`.

## Logo dan ikon aplikasi

Logo digambar dengan kode di `lib/widgets/logo.dart` (topi wisuda di atas buku
terbuka). Setelah mengubahnya, buat ulang semua ikon:

```bash
flutter test tool/ekspor_ikon_test.dart
```

```bash
python tool/ikon_ios.py
```

## Memeriksa tampilan tanpa perangkat

Skrip ini memotret setiap halaman mode demo ke PNG (390×844):

```bash
flutter test tool/tangkap_layar_test.dart --dart-define=TANGKAP_DIR=build/tangkap
```

## Uang kas, pengumuman, dan rekap kehadiran

- **Uang Kas**: saldo dan arus kas bulan ini untuk semua anggota, status iuran
  pribadi (progres pekan dan tunggakan), dan riwayat kas kelas. Iuran orang
  lain tampil digabung per tanggal tanpa nama. Admin mencatat iuran,
  pemasukan, dan pengeluaran, melihat status iuran tiap anggota, dan mengatur
  nominal iuran mingguan.
- **Pengumuman**: admin dan dosen membuat pengumuman (bisa ditandai penting);
  yang terbaru tampil di beranda.
- **Rekap Kehadiran**: persentase kehadiran pribadi di beranda dan rincian per
  mata kuliah, dengan tanda untuk mata kuliah di bawah 75%.

Fitur ini butuh migrasi `supabase/migrations/20261120090000_uang_kas_dan_pengumuman.sql`.
Migrasi aman dijalankan pada tabel `kas_transaksi` yang sudah ada: kolom hanya
ditambah bila belum ada dan nilai jenis lama (masuk/keluar) diseragamkan.

```bash
npx supabase db push
```

## Rekap dan ekspor (PDF/Excel)

Menu **Rekap** (admin kelas dan dosen) menampilkan pratinjau lalu mengekspor
dokumen dengan format daftar hadir kampus (A4 lanskap, kop UNM, 15 mahasiswa
per halaman, kolom pertemuan 1–7, UTS, 8–14, UAS):

- **Absen**: daftar hadir per mata kuliah (H = hadir, A = tidak hadir) dan
  lembar rekapitulasi persentase kehadiran dengan batas 75%.
- **Tugas**: status pengumpulan tiap tugas per mahasiswa.
- **Kas** (admin): buku kas dengan saldo berjalan dan status iuran anggota.

Berkas dibagikan lewat lembar bagikan sistem (simpan ke Files, Drive, WhatsApp).
Kolom STAMBUK diisi dari `users.username`, jadi isi username dengan NIM.
Sesi yang masih berjalan belum dihitung. Fitur ini butuh migrasi
`supabase/migrations/20261121090000_rekap_dan_ekspor.sql` (fungsi
`daftar_mahasiswa()` dan `rekap_absen()`).

Contoh berkas dari data demo:

```bash
flutter test tool/contoh_rekap_test.dart --dart-define=REKAP_DIR=build/rekap
```
