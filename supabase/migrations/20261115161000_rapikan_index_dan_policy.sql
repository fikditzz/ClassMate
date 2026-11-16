-- Merapikan hasil pemeriksaan `supabase db advisors` setelah migrasi sebelumnya.
--
-- 1. Skema awal sudah punya index idx_*; index buatan migrasi sebelumnya yang
--    sama atau sudah tercakup index komposit dihapus.
-- 2. Policy "dikelola" memakai `for all`, sehingga untuk SELECT ada dua policy
--    yang dievaluasi. Policy itu dipecah per perintah (insert, update, delete).
--
-- Peringatan "security definer function executable" untuk absen(),
-- pengguna_saya(), pengguna_saya_id(), dan peran_saya() disengaja: fungsi itu
-- memang dipanggil aplikasi atau RLS dan hanya mengembalikan data pemanggil.

drop index public.jadwal_mata_kuliah_id_idx;
drop index public.kehadiran_user_id_idx;
drop index public.pengumpulan_user_id_idx;
drop index public.tugas_mata_kuliah_id_idx;
drop index public.users_kelas_id_idx;
drop index public.kas_transaksi_kelas_id_idx;     -- tercakup idx_kas_kelas_tanggal
drop index public.sesi_absensi_mata_kuliah_id_idx; -- tercakup idx_sesi_matkul_tanggal

-- users, kelas, kas_transaksi: dikelola admin
drop policy "users: dikelola admin" on public.users;
create policy "users: ditambah admin" on public.users
  for insert to authenticated with check ((select public.is_admin()));
create policy "users: diubah admin" on public.users
  for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
create policy "users: dihapus admin" on public.users
  for delete to authenticated using ((select public.is_admin()));

drop policy "kelas: dikelola admin" on public.kelas;
create policy "kelas: ditambah admin" on public.kelas
  for insert to authenticated with check ((select public.is_admin()));
create policy "kelas: diubah admin" on public.kelas
  for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
create policy "kelas: dihapus admin" on public.kelas
  for delete to authenticated using ((select public.is_admin()));

drop policy "kas_transaksi: dikelola admin" on public.kas_transaksi;
create policy "kas_transaksi: ditambah admin" on public.kas_transaksi
  for insert to authenticated with check ((select public.is_admin()));
create policy "kas_transaksi: diubah admin" on public.kas_transaksi
  for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
create policy "kas_transaksi: dihapus admin" on public.kas_transaksi
  for delete to authenticated using ((select public.is_admin()));

-- mata_kuliah, jadwal, sesi_absensi, tugas: dikelola admin dan dosen
drop policy "mata_kuliah: dikelola pengelola" on public.mata_kuliah;
create policy "mata_kuliah: ditambah pengelola" on public.mata_kuliah
  for insert to authenticated with check ((select public.boleh_kelola()));
create policy "mata_kuliah: diubah pengelola" on public.mata_kuliah
  for update to authenticated
  using ((select public.boleh_kelola())) with check ((select public.boleh_kelola()));
create policy "mata_kuliah: dihapus pengelola" on public.mata_kuliah
  for delete to authenticated using ((select public.boleh_kelola()));

drop policy "jadwal: dikelola pengelola" on public.jadwal;
create policy "jadwal: ditambah pengelola" on public.jadwal
  for insert to authenticated with check ((select public.boleh_kelola()));
create policy "jadwal: diubah pengelola" on public.jadwal
  for update to authenticated
  using ((select public.boleh_kelola())) with check ((select public.boleh_kelola()));
create policy "jadwal: dihapus pengelola" on public.jadwal
  for delete to authenticated using ((select public.boleh_kelola()));

drop policy "sesi_absensi: dikelola pengelola" on public.sesi_absensi;
create policy "sesi_absensi: ditambah pengelola" on public.sesi_absensi
  for insert to authenticated with check ((select public.boleh_kelola()));
create policy "sesi_absensi: diubah pengelola" on public.sesi_absensi
  for update to authenticated
  using ((select public.boleh_kelola())) with check ((select public.boleh_kelola()));
create policy "sesi_absensi: dihapus pengelola" on public.sesi_absensi
  for delete to authenticated using ((select public.boleh_kelola()));

drop policy "tugas: dikelola pengelola" on public.tugas;
create policy "tugas: ditambah pengelola" on public.tugas
  for insert to authenticated with check ((select public.boleh_kelola()));
create policy "tugas: diubah pengelola" on public.tugas
  for update to authenticated
  using ((select public.boleh_kelola())) with check ((select public.boleh_kelola()));
create policy "tugas: dihapus pengelola" on public.tugas
  for delete to authenticated using ((select public.boleh_kelola()));
