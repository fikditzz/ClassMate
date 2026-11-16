-- ClassMate: mengamankan skema yang sudah ada dan menyesuaikannya dengan aplikasi.
--
-- Sebelum migrasi ini RLS mati di semua tabel, sementara role `anon` dan
-- `authenticated` punya hak penuh. Siapa pun yang memegang publishable key
-- bisa membaca, mengisi, dan menghapus semua data tanpa login.
--
-- Aturannya mengikuti firestore.rules:
--   * hanya email yang terdaftar di tabel users (dan sudah terverifikasi)
--     yang boleh mengakses data;
--   * admin dan dosen ("pengelola") mengelola mata kuliah, jadwal, sesi, tugas;
--   * hanya admin yang mengelola akun, kelas, dan uang kas;
--   * token absen hanya bisa dibaca pengelola;
--   * kehadiran dicatat lewat fungsi absen() dan tidak bisa diubah atau dihapus;
--   * pengumpulan hanya bisa dibuat atau diganti sebelum tenggat.
--
-- Tanggal dan jam sesi absen dibaca sebagai WITA (Asia/Makassar).


-- 1. Struktur ------------------------------------------------------------------

-- Token dipisah dari sesi_absensi agar anggota bisa melihat sesi tanpa tokennya.
create table public.sesi_token (
  sesi_id bigint primary key references public.sesi_absensi (id) on delete cascade,
  token varchar(12) not null unique
);

insert into public.sesi_token (sesi_id, token)
select id, upper(token) from public.sesi_absensi;

alter table public.sesi_absensi drop column token;

alter table public.mata_kuliah
  add column kode varchar(20),
  add column sks smallint check (sks between 0 and 24),
  add column dosen text[] not null default '{}';

-- Email dicocokkan tanpa membedakan huruf besar dan kecil.
create unique index users_email_google_lower_key
  on public.users (lower(email_google));

-- Index untuk foreign key dan kolom yang sering dipakai menyaring.
create index on public.users (kelas_id);
create index on public.jadwal (mata_kuliah_id);
create index on public.sesi_absensi (mata_kuliah_id);
create index on public.sesi_absensi (tanggal);
create index on public.kehadiran (user_id);
create index on public.tugas (mata_kuliah_id);
create index on public.tugas (dibuat_oleh);
create index on public.tugas (tenggat);
create index on public.pengumpulan (user_id);
create index on public.device_token (user_id);
create index on public.kas_transaksi (kelas_id);
create index on public.kas_transaksi (user_id);


-- 2. Fungsi bantu untuk RLS -----------------------------------------------------

-- ID baris users milik pengguna yang login, atau null bila emailnya tidak
-- terdaftar atau belum terverifikasi.
create function public.pengguna_saya_id()
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select u.id
  from public.users u
  join auth.users a on lower(a.email) = lower(u.email_google)
  where a.id = auth.uid()
    and a.email_confirmed_at is not null
$$;

create function public.peran_saya()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select u.peran from public.users u where u.id = public.pengguna_saya_id()
$$;

-- Admin dan dosen boleh mengelola data perkuliahan.
create function public.boleh_kelola()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(public.peran_saya() in ('admin', 'dosen'), false)
$$;

create function public.is_admin()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(public.peran_saya() = 'admin', false)
$$;


-- 3. Fungsi untuk aplikasi ------------------------------------------------------

-- Data akun setelah login. null berarti email tidak terdaftar.
create function public.pengguna_saya()
returns json
language sql
stable
security definer
set search_path = ''
as $$
  select json_build_object(
    'id', u.id,
    'nama', u.nama,
    'username', u.username,
    'email', lower(u.email_google),
    'peran', u.peran,
    'kelas_id', u.kelas_id,
    'nama_kelas', k.nama_kelas,
    'angkatan', k.angkatan
  )
  from public.users u
  left join public.kelas k on k.id = u.kelas_id
  where u.id = public.pengguna_saya_id()
$$;

-- Membuat sesi beserta tokennya dalam satu transaksi. Berjalan dengan hak
-- pemanggil, jadi RLS tetap menolak bila pemanggil bukan pengelola.
create function public.buat_sesi(
  p_mata_kuliah_id bigint,
  p_tanggal date,
  p_jam_mulai time,
  p_jam_selesai time,
  p_token text
)
returns bigint
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_id bigint;
begin
  insert into public.sesi_absensi (mata_kuliah_id, tanggal, jam_mulai, jam_selesai)
  values (p_mata_kuliah_id, p_tanggal, p_jam_mulai, p_jam_selesai)
  returning id into v_id;

  insert into public.sesi_token (sesi_id, token)
  values (v_id, upper(trim(p_token)));

  return v_id;
end;
$$;

-- Mencatat kehadiran pengguna yang login. Token, status, dan jam sesi (WITA)
-- diperiksa di server. Absen ganda ditolak oleh constraint unique_kehadiran.
create function public.absen(p_sesi_id bigint, p_token text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user bigint := public.pengguna_saya_id();
  v_sesi public.sesi_absensi;
  v_token text;
  v_sekarang timestamp := now() at time zone 'Asia/Makassar';
begin
  if v_user is null then
    raise exception 'tidak_terdaftar';
  end if;

  select * into v_sesi from public.sesi_absensi where id = p_sesi_id;
  select t.token into v_token from public.sesi_token t where t.sesi_id = p_sesi_id;

  if v_sesi.id is null
     or v_sesi.status <> 'aktif'
     or v_sekarang < v_sesi.tanggal + v_sesi.jam_mulai
     or v_sekarang >= v_sesi.tanggal + v_sesi.jam_selesai
     or v_token is distinct from upper(trim(p_token)) then
    raise exception 'token_salah_atau_sesi_berakhir';
  end if;

  insert into public.kehadiran (sesi_id, user_id) values (p_sesi_id, v_user);
exception
  when unique_violation then
    raise exception 'sudah_absen';
end;
$$;

-- Waktu unggah selalu waktu server, bukan kiriman aplikasi.
create function public.isi_waktu_upload()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.waktu_upload := now();
  return new;
end;
$$;

create trigger pengumpulan_isi_waktu_upload
before insert or update on public.pengumpulan
for each row execute function public.isi_waktu_upload();

-- Pembuat tugas diisi otomatis dari akun yang login.
alter table public.tugas
  alter column dibuat_oleh set default public.pengguna_saya_id();

revoke execute on function
  public.pengguna_saya_id(),
  public.peran_saya(),
  public.boleh_kelola(),
  public.is_admin(),
  public.pengguna_saya(),
  public.buat_sesi(bigint, date, time, time, text),
  public.absen(bigint, text),
  public.isi_waktu_upload()
from public, anon;

grant execute on function
  public.pengguna_saya_id(),
  public.peran_saya(),
  public.boleh_kelola(),
  public.is_admin(),
  public.pengguna_saya(),
  public.buat_sesi(bigint, date, time, time, text),
  public.absen(bigint, text)
to authenticated;


-- 4. Hak akses dan RLS -----------------------------------------------------------

-- Aplikasi selalu meminta login, jadi anon tidak perlu akses ke tabel mana pun.
revoke all on all tables in schema public from anon;
revoke truncate, references, trigger on all tables in schema public from authenticated;
-- Kehadiran hanya ditulis lewat absen().
revoke insert, update, delete on public.kehadiran from authenticated;

alter table public.users enable row level security;
alter table public.kelas enable row level security;
alter table public.mata_kuliah enable row level security;
alter table public.jadwal enable row level security;
alter table public.sesi_absensi enable row level security;
alter table public.sesi_token enable row level security;
alter table public.kehadiran enable row level security;
alter table public.tugas enable row level security;
alter table public.pengumpulan enable row level security;
alter table public.device_token enable row level security;
alter table public.kas_transaksi enable row level security;

-- users
create policy "users: dibaca pemilik atau pengelola"
  on public.users for select to authenticated
  using (id = (select public.pengguna_saya_id()) or (select public.boleh_kelola()));
create policy "users: dikelola admin"
  on public.users for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- kelas
create policy "kelas: dibaca pengguna terdaftar"
  on public.kelas for select to authenticated
  using ((select public.pengguna_saya_id()) is not null);
create policy "kelas: dikelola admin"
  on public.kelas for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

-- mata_kuliah
create policy "mata_kuliah: dibaca pengguna terdaftar"
  on public.mata_kuliah for select to authenticated
  using ((select public.pengguna_saya_id()) is not null);
create policy "mata_kuliah: dikelola pengelola"
  on public.mata_kuliah for all to authenticated
  using ((select public.boleh_kelola()))
  with check ((select public.boleh_kelola()));

-- jadwal
create policy "jadwal: dibaca pengguna terdaftar"
  on public.jadwal for select to authenticated
  using ((select public.pengguna_saya_id()) is not null);
create policy "jadwal: dikelola pengelola"
  on public.jadwal for all to authenticated
  using ((select public.boleh_kelola()))
  with check ((select public.boleh_kelola()));

-- sesi_absensi
create policy "sesi_absensi: dibaca pengguna terdaftar"
  on public.sesi_absensi for select to authenticated
  using ((select public.pengguna_saya_id()) is not null);
create policy "sesi_absensi: dikelola pengelola"
  on public.sesi_absensi for all to authenticated
  using ((select public.boleh_kelola()))
  with check ((select public.boleh_kelola()));

-- sesi_token: hanya pengelola
create policy "sesi_token: hanya pengelola"
  on public.sesi_token for all to authenticated
  using ((select public.boleh_kelola()))
  with check ((select public.boleh_kelola()));

-- kehadiran: dibaca saja; dibuat lewat absen()
create policy "kehadiran: dibaca pemilik atau pengelola"
  on public.kehadiran for select to authenticated
  using (user_id = (select public.pengguna_saya_id()) or (select public.boleh_kelola()));

-- tugas
create policy "tugas: dibaca pengguna terdaftar"
  on public.tugas for select to authenticated
  using ((select public.pengguna_saya_id()) is not null);
create policy "tugas: dikelola pengelola"
  on public.tugas for all to authenticated
  using ((select public.boleh_kelola()))
  with check ((select public.boleh_kelola()));

-- pengumpulan
create policy "pengumpulan: dibaca pemilik atau pengelola"
  on public.pengumpulan for select to authenticated
  using (user_id = (select public.pengguna_saya_id()) or (select public.boleh_kelola()));
create policy "pengumpulan: dibuat pemilik sebelum tenggat"
  on public.pengumpulan for insert to authenticated
  with check (
    user_id = (select public.pengguna_saya_id())
    and now() < (select t.tenggat from public.tugas t where t.id = pengumpulan.tugas_id)
  );
create policy "pengumpulan: diganti pemilik sebelum tenggat"
  on public.pengumpulan for update to authenticated
  using (user_id = (select public.pengguna_saya_id()))
  with check (
    user_id = (select public.pengguna_saya_id())
    and now() < (select t.tenggat from public.tugas t where t.id = pengumpulan.tugas_id)
  );

-- device_token: milik sendiri
create policy "device_token: milik sendiri"
  on public.device_token for all to authenticated
  using (user_id = (select public.pengguna_saya_id()))
  with check (user_id = (select public.pengguna_saya_id()));

-- kas_transaksi
create policy "kas_transaksi: dibaca pemilik atau admin"
  on public.kas_transaksi for select to authenticated
  using (user_id = (select public.pengguna_saya_id()) or (select public.is_admin()));
create policy "kas_transaksi: dikelola admin"
  on public.kas_transaksi for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));


-- 5. Realtime --------------------------------------------------------------------

alter publication supabase_realtime add table
  public.mata_kuliah,
  public.jadwal,
  public.sesi_absensi,
  public.kehadiran,
  public.tugas,
  public.pengumpulan;
