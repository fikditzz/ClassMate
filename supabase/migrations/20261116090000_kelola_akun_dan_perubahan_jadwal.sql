-- Fitur admin: kelola akun, kelola mata kuliah, dan perubahan jadwal per
-- pertemuan (libur, pindah, kuliah tambahan).
--
-- Akun login (Supabase Auth) dibuat dan diubah lewat Edge Function
-- `kelola-akun`, karena butuh kunci rahasia yang tidak boleh ada di aplikasi.


-- 1. Akun --------------------------------------------------------------------

-- Email selalu disimpan huruf kecil agar mudah dicocokkan.
update public.users set email_google = lower(email_google)
where email_google <> lower(email_google);
alter table public.users
  add constraint chk_users_email_kecil check (email_google = lower(email_google));

-- Kelas pengguna yang login; dipakai sebagai nilai bawaan saat admin menambah
-- mata kuliah.
create function public.kelas_saya_id()
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select u.kelas_id from public.users u where u.id = public.pengguna_saya_id()
$$;

alter table public.mata_kuliah
  alter column kelas_id set default public.kelas_saya_id();

-- Daftar akun untuk halaman Kelola Akun, termasuk apakah akun sudah bisa
-- login. Hanya admin; selain admin mendapat daftar kosong.
create function public.daftar_akun()
returns table (
  id bigint,
  nama text,
  username text,
  email text,
  peran text,
  punya_login boolean,
  login_terakhir timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select u.id, u.nama, u.username, u.email_google, u.peran,
         a.id is not null, a.last_sign_in_at
  from public.users u
  left join auth.users a on lower(a.email) = u.email_google
  where public.is_admin()
  order by u.peran, u.nama
$$;

-- Dipakai Edge Function (service_role) untuk mencari akun Auth dari email.
create function public.auth_id_dari_email(p_email text)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select a.id from auth.users a where lower(a.email) = lower(p_email) limit 1
$$;

revoke execute on function
  public.kelas_saya_id(),
  public.daftar_akun(),
  public.auth_id_dari_email(text)
from public, anon;
grant execute on function public.kelas_saya_id(), public.daftar_akun()
  to authenticated;
revoke execute on function public.auth_id_dari_email(text) from authenticated;
grant execute on function public.auth_id_dari_email(text) to service_role;


-- 2. Perubahan jadwal per pertemuan ------------------------------------------
--
-- libur    : pertemuan jadwal_id pada tanggal_asal ditiadakan.
-- pindah   : pertemuan jadwal_id pada tanggal_asal dipindah ke tanggal + jam.
-- tambahan : kuliah sekali di tanggal + jam (pengganti atau tambahan).

create table public.perubahan_jadwal (
  id bigint generated always as identity primary key,
  jenis varchar(10) not null check (jenis in ('libur', 'pindah', 'tambahan')),
  mata_kuliah_id bigint not null references public.mata_kuliah (id) on delete cascade,
  jadwal_id bigint references public.jadwal (id) on delete cascade,
  tanggal_asal date,
  tanggal date,
  jam_mulai time,
  jam_selesai time,
  ruang varchar(100),
  keterangan text,
  dibuat_oleh bigint references public.users (id) on delete set null
    default public.pengguna_saya_id(),
  dibuat_pada timestamptz not null default now(),
  constraint chk_perubahan_asal check (
    (jenis = 'tambahan') = (jadwal_id is null and tanggal_asal is null)
  ),
  constraint chk_perubahan_tujuan check (
    case when jenis = 'libur'
      then tanggal is null and jam_mulai is null and jam_selesai is null
      else tanggal is not null and jam_mulai is not null
        and jam_selesai is not null and jam_selesai > jam_mulai
    end
  ),
  -- Satu pertemuan hanya punya satu perubahan.
  constraint unique_perubahan_pertemuan unique (jadwal_id, tanggal_asal)
);

create index on public.perubahan_jadwal (tanggal);
create index on public.perubahan_jadwal (mata_kuliah_id);
create index on public.perubahan_jadwal (dibuat_oleh);

-- Pertemuan yang diubah harus sesuai hari jadwalnya, dan mata kuliahnya ikut
-- jadwal tersebut.
create function public.periksa_perubahan_jadwal()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_jadwal public.jadwal;
begin
  if new.jadwal_id is not null then
    select * into v_jadwal from public.jadwal where id = new.jadwal_id;
    new.mata_kuliah_id := v_jadwal.mata_kuliah_id;
    if extract(isodow from new.tanggal_asal)::int <> array_position(
      array['Senin','Selasa','Rabu','Kamis','Jumat','Sabtu','Minggu']::varchar[],
      v_jadwal.hari
    ) then
      raise exception 'tanggal_asal_bukan_hari_jadwal';
    end if;
  end if;
  return new;
end;
$$;

create trigger perubahan_jadwal_periksa
before insert or update on public.perubahan_jadwal
for each row execute function public.periksa_perubahan_jadwal();

revoke execute on function public.periksa_perubahan_jadwal() from public, anon;

revoke all on public.perubahan_jadwal from anon;
revoke truncate, references, trigger on public.perubahan_jadwal from authenticated;
alter table public.perubahan_jadwal enable row level security;

create policy "perubahan_jadwal: dibaca pengguna terdaftar"
  on public.perubahan_jadwal for select to authenticated
  using ((select public.pengguna_saya_id()) is not null);
create policy "perubahan_jadwal: ditambah pengelola"
  on public.perubahan_jadwal for insert to authenticated
  with check ((select public.boleh_kelola()));
create policy "perubahan_jadwal: diubah pengelola"
  on public.perubahan_jadwal for update to authenticated
  using ((select public.boleh_kelola())) with check ((select public.boleh_kelola()));
create policy "perubahan_jadwal: dihapus pengelola"
  on public.perubahan_jadwal for delete to authenticated
  using ((select public.boleh_kelola()));

alter publication supabase_realtime add table public.perubahan_jadwal;
