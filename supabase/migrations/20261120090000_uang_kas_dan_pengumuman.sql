-- Fitur: uang kas di aplikasi dan pengumuman kelas.
--
-- Struktur kas_transaksi yang lama tidak tercatat di migrasi, jadi bagian 1
-- dibuat aman dijalankan apa pun bentuk tabelnya: kolom hanya ditambah bila
-- belum ada, dan nilai jenis lama ("masuk"/"keluar", huruf besar, jumlah
-- negatif) diseragamkan.
--
-- RLS kas_transaksi tetap: anggota hanya membaca baris miliknya. Ringkasan
-- dan riwayat kelas dibaca lewat fungsi security definer; untuk anggota,
-- iuran orang lain digabung per tanggal tanpa nama.


-- 1. Kas: kolom yang dipakai aplikasi ------------------------------------------

alter table public.kas_transaksi
  add column if not exists jenis varchar(20),
  add column if not exists jumlah bigint,
  add column if not exists tanggal date default current_date,
  add column if not exists keterangan text,
  add column if not exists user_id bigint references public.users (id) on delete set null,
  add column if not exists dibuat_oleh bigint references public.users (id) on delete set null
    default public.pengguna_saya_id(),
  add column if not exists dibuat_pada timestamptz not null default now();

-- Batasan lama pada kolom jenis dilepas sebelum nilainya diseragamkan.
do $$
declare
  c record;
begin
  for c in
    select conname from pg_constraint
    where conrelid = 'public.kas_transaksi'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%jenis%'
  loop
    execute format('alter table public.kas_transaksi drop constraint %I', c.conname);
  end loop;
end;
$$;

-- jenis bisa saja enum atau varchar pendek; jadikan varchar biasa.
alter table public.kas_transaksi
  alter column jenis type varchar(20) using jenis::text;

update public.kas_transaksi
set jenis = case lower(jenis)
  when 'keluar' then 'pengeluaran'
  when 'masuk' then 'pemasukan'
  else lower(jenis)
end
where jenis is distinct from lower(jenis)
   or lower(jenis) in ('keluar', 'masuk');

-- Jumlah negatif dulu berarti uang keluar.
update public.kas_transaksi
set jenis = 'pengeluaran', jumlah = -jumlah
where jumlah < 0;

update public.kas_transaksi set jenis = 'pemasukan'
where jenis is null or jenis not in ('iuran', 'pemasukan', 'pengeluaran');

alter table public.kas_transaksi
  add constraint chk_kas_jenis
    check (jenis in ('iuran', 'pemasukan', 'pengeluaran')) not valid,
  add constraint chk_kas_jumlah check (jumlah > 0) not valid,
  add constraint chk_kas_iuran_anggota
    check (jenis <> 'iuran' or user_id is not null) not valid;

-- Transaksi baru otomatis masuk ke kelas admin yang mencatat.
alter table public.kas_transaksi
  alter column kelas_id set default public.kelas_saya_id();

create index if not exists kas_transaksi_dibuat_oleh_idx
  on public.kas_transaksi (dibuat_oleh);

-- Iuran mingguan per kelas.
alter table public.kelas
  add column if not exists iuran_nominal integer check (iuran_nominal > 0),
  add column if not exists iuran_mulai date;


-- 2. Kas: fungsi untuk aplikasi ------------------------------------------------

-- Saldo dan arus kas bulan ini (WITA) untuk semua anggota terdaftar.
create or replace function public.ringkasan_kas()
returns json
language sql
stable
security definer
set search_path = ''
as $$
  with kas as (
    select t.jenis::text as jenis, t.jumlah::bigint as jumlah,
           t.tanggal::date as tanggal
    from public.kas_transaksi t
    where t.kelas_id = public.kelas_saya_id()
  ),
  bulan as (
    select date_trunc('month', now() at time zone 'Asia/Makassar')::date as awal
  ),
  aturan as (
    select c.iuran_nominal, c.iuran_mulai
    from public.kelas c
    where c.id = public.kelas_saya_id()
  )
  select json_build_object(
    'saldo', coalesce(sum(
      case when k.jenis = 'pengeluaran' then -k.jumlah else k.jumlah end
    ), 0),
    'masuk_bulan_ini', coalesce(sum(k.jumlah) filter (
      where k.jenis <> 'pengeluaran' and k.tanggal >= b.awal
    ), 0),
    'keluar_bulan_ini', coalesce(sum(k.jumlah) filter (
      where k.jenis = 'pengeluaran' and k.tanggal >= b.awal
    ), 0),
    'iuran_nominal', (select a.iuran_nominal from aturan a),
    'iuran_mulai', (select a.iuran_mulai from aturan a)
  )
  from bulan b
  left join kas k on true
$$;

-- Riwayat kas kelas, terbaru di atas. Admin melihat semua baris beserta
-- nama; anggota melihat pemasukan dan pengeluaran, sedangkan iuran
-- digabung per tanggal tanpa nama.
create or replace function public.riwayat_kas_kelas()
returns table (
  id text,
  jenis text,
  jumlah bigint,
  tanggal date,
  keterangan text,
  user_id bigint,
  nama_anggota text,
  jumlah_anggota integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select * from (
    select t.id::text, t.jenis::text, t.jumlah::bigint, t.tanggal::date,
           t.keterangan::text, t.user_id, u.nama::text, 0
    from public.kas_transaksi t
    left join public.users u on u.id = t.user_id
    where t.kelas_id = public.kelas_saya_id()
      and (public.is_admin() or t.jenis <> 'iuran')
    union all
    select null, 'iuran', sum(t.jumlah)::bigint, t.tanggal::date,
           'Iuran kas', null, null, count(t.jumlah)::integer
    from public.kas_transaksi t
    where t.kelas_id = public.kelas_saya_id()
      and not public.is_admin()
      and t.jenis = 'iuran'
    group by t.tanggal::date
  ) r
  order by r.tanggal desc, r.id desc nulls last
$$;

-- Total iuran tiap anggota kelas (selain dosen). Khusus admin.
create or replace function public.status_iuran()
returns table (
  user_id bigint,
  nama text,
  total bigint,
  kali integer,
  terakhir date
)
language sql
stable
security definer
set search_path = ''
as $$
  select u.id, u.nama::text, coalesce(sum(t.jumlah), 0)::bigint,
         count(t.jumlah)::integer, max(t.tanggal)::date
  from public.users u
  left join public.kas_transaksi t
    on t.user_id = u.id and t.jenis = 'iuran'
  where public.is_admin()
    and u.kelas_id = public.kelas_saya_id()
    and u.peran <> 'dosen'
  group by u.id, u.nama
  order by u.nama
$$;

-- Mengatur nominal iuran mingguan dan pekan pertamanya. Khusus admin.
create or replace function public.atur_iuran(p_nominal integer, p_mulai date)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'hanya_admin' using errcode = '42501';
  end if;
  if p_nominal is null or p_nominal <= 0 or p_mulai is null then
    raise exception 'aturan_iuran_tidak_valid' using errcode = '22023';
  end if;
  update public.kelas
  set iuran_nominal = p_nominal, iuran_mulai = p_mulai
  where id = public.kelas_saya_id();
end;
$$;


-- 3. Pengumuman kelas ---------------------------------------------------------

create table public.pengumuman (
  id bigint generated always as identity primary key,
  kelas_id bigint not null default public.kelas_saya_id()
    references public.kelas (id) on delete cascade,
  judul varchar(120) not null check (length(trim(judul)) > 0),
  isi text not null default '',
  penting boolean not null default false,
  dibuat_oleh bigint references public.users (id) on delete set null
    default public.pengguna_saya_id(),
  dibuat_pada timestamptz not null default now()
);

create index on public.pengumuman (kelas_id, dibuat_pada desc);
create index on public.pengumuman (dibuat_oleh);

revoke all on public.pengumuman from anon;
revoke truncate, references, trigger on public.pengumuman from authenticated;
alter table public.pengumuman enable row level security;

create policy "pengumuman: dibaca anggota kelas"
  on public.pengumuman for select to authenticated
  using (kelas_id = (select public.kelas_saya_id()));
create policy "pengumuman: ditambah pengelola"
  on public.pengumuman for insert to authenticated
  with check (
    (select public.boleh_kelola()) and kelas_id = (select public.kelas_saya_id())
  );
create policy "pengumuman: diubah pengelola"
  on public.pengumuman for update to authenticated
  using (
    (select public.boleh_kelola()) and kelas_id = (select public.kelas_saya_id())
  )
  with check (
    (select public.boleh_kelola()) and kelas_id = (select public.kelas_saya_id())
  );
create policy "pengumuman: dihapus pengelola"
  on public.pengumuman for delete to authenticated
  using (
    (select public.boleh_kelola()) and kelas_id = (select public.kelas_saya_id())
  );

-- Daftar pengumuman beserta nama pembuatnya (tabel users tidak dibuka ke
-- semua anggota).
create or replace function public.daftar_pengumuman()
returns table (
  id bigint,
  judul text,
  isi text,
  penting boolean,
  nama_pembuat text,
  dibuat_pada timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.judul::text, p.isi, p.penting, u.nama::text, p.dibuat_pada
  from public.pengumuman p
  left join public.users u on u.id = p.dibuat_oleh
  where p.kelas_id = public.kelas_saya_id()
  order by p.dibuat_pada desc
  limit 100
$$;


-- 4. Hak akses fungsi ---------------------------------------------------------

revoke execute on function
  public.ringkasan_kas(),
  public.riwayat_kas_kelas(),
  public.status_iuran(),
  public.atur_iuran(integer, date),
  public.daftar_pengumuman()
from public, anon;
grant execute on function
  public.ringkasan_kas(),
  public.riwayat_kas_kelas(),
  public.status_iuran(),
  public.atur_iuran(integer, date),
  public.daftar_pengumuman()
to authenticated;
