-- Rekap untuk ekspor PDF/Excel: daftar mahasiswa dan daftar hadir per mata
-- kuliah. Khusus pengelola (admin kelas dan dosen); selain itu hasilnya
-- kosong.


-- Mahasiswa kelas pengelola (termasuk admin kelas, tanpa dosen).
create or replace function public.daftar_mahasiswa()
returns table (
  id bigint,
  nama text,
  username text
)
language sql
stable
security definer
set search_path = ''
as $$
  select u.id, u.nama::text, u.username::text
  from public.users u
  where public.boleh_kelola()
    and u.kelas_id = public.kelas_saya_id()
    and u.peran <> 'dosen'
  order by u.username, u.nama
$$;

-- Sesi satu mata kuliah beserta kehadirannya, untuk daftar hadir.
create or replace function public.rekap_absen(p_mata_kuliah_id bigint)
returns json
language sql
stable
security definer
set search_path = ''
as $$
  select json_build_object(
    'sesi', coalesce((
      select json_agg(json_build_object(
        'id', s.id,
        'tanggal', s.tanggal,
        'jam_mulai', s.jam_mulai,
        'jam_selesai', s.jam_selesai,
        'status', s.status
      ) order by s.tanggal, s.jam_mulai)
      from public.sesi_absensi s
      where s.mata_kuliah_id = p_mata_kuliah_id
    ), '[]'::json),
    'hadir', coalesce((
      select json_agg(json_build_object(
        'sesi_id', k.sesi_id,
        'user_id', k.user_id
      ))
      from public.kehadiran k
      join public.sesi_absensi s on s.id = k.sesi_id
      where s.mata_kuliah_id = p_mata_kuliah_id
    ), '[]'::json)
  )
  where public.boleh_kelola()
    and exists (
      select 1 from public.mata_kuliah m
      where m.id = p_mata_kuliah_id and m.kelas_id = public.kelas_saya_id()
    )
$$;

revoke execute on function
  public.daftar_mahasiswa(),
  public.rekap_absen(bigint)
from public, anon;
grant execute on function
  public.daftar_mahasiswa(),
  public.rekap_absen(bigint)
to authenticated;
