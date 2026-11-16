// Edge Function: admin kelas mengelola akun ClassMate.
//
// Aksi (body JSON, field `aksi`):
//   buat           { nama, username, email, peran, password }
//   ubah           { id, nama, username, email, peran }
//   atur_password  { id, password }
//   hapus          { id }
//
// Pemanggil harus login dan berperan `admin` di tabel users. Kunci rahasia
// hanya ada di server Supabase, tidak pernah di aplikasi.
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const PERAN = ["admin", "dosen", "mahasiswa"];
const PANJANG_PASSWORD = 8;

class Gagal extends Error {
  constructor(public status: number, pesan: string) {
    super(pesan);
  }
}

function balas(status: number, isi: unknown) {
  return new Response(JSON.stringify(isi), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

/** Secret key baru (SUPABASE_SECRET_KEYS) atau service_role lama. */
function kunciRahasia(): string {
  const baru = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (baru) {
    try {
      const daftar = JSON.parse(baru) as Record<string, string>;
      const kunci = daftar["default"] ?? Object.values(daftar)[0];
      if (kunci) return kunci;
    } catch (_) {
      // lanjut ke kunci lama
    }
  }
  const lama = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (lama) return lama;
  throw new Gagal(500, "Kunci rahasia Supabase tidak tersedia di server.");
}

function teks(nilai: unknown, nama: string, wajib = true): string {
  const s = typeof nilai === "string" ? nilai.trim() : "";
  if (wajib && !s) throw new Gagal(400, `${nama} wajib diisi.`);
  return s;
}

function idAkun(nilai: unknown): number {
  const id = Number(nilai);
  if (!Number.isInteger(id) || id <= 0) throw new Gagal(400, "ID akun tidak valid.");
  return id;
}

function password(nilai: unknown): string {
  if (typeof nilai !== "string" || nilai.length < PANJANG_PASSWORD) {
    throw new Gagal(400, `Password minimal ${PANJANG_PASSWORD} karakter.`);
  }
  return nilai;
}

function dataAkun(body: Record<string, unknown>) {
  const peran = teks(body.peran, "Peran");
  if (!PERAN.includes(peran)) throw new Gagal(400, "Peran tidak dikenal.");
  return {
    nama: teks(body.nama, "Nama"),
    username: teks(body.username, "Username").toLowerCase(),
    email_google: teks(body.email, "Email").toLowerCase(),
    peran,
  };
}

/** Pesan yang mudah dipahami untuk pelanggaran constraint tabel users. */
function pesanDb(e: { code?: string; message?: string }): Gagal {
  const m = e.message ?? "";
  if (e.code === "23505" && m.includes("username")) {
    return new Gagal(409, "Username sudah dipakai akun lain.");
  }
  if (e.code === "23505" && m.includes("email")) {
    return new Gagal(409, "Email sudah terdaftar.");
  }
  if (e.code === "23514" && m.includes("email")) {
    return new Gagal(400, "Format email tidak valid.");
  }
  return new Gagal(400, `Gagal menyimpan akun: ${m}`);
}

function pesanAuth(e: { message?: string; code?: string }): Gagal {
  const m = e.message ?? "";
  if (e.code === "weak_password" || /password/i.test(m)) {
    return new Gagal(400, `Password ditolak: ${m}`);
  }
  if (e.code === "email_exists" || /already/i.test(m)) {
    return new Gagal(409, "Email sudah dipakai akun login lain.");
  }
  return new Gagal(400, `Gagal mengatur akun login: ${m}`);
}

async function authId(db: SupabaseClient, email: string): Promise<string | null> {
  const { data, error } = await db.rpc("auth_id_dari_email", { p_email: email });
  if (error) throw new Gagal(500, `Gagal mencari akun login: ${error.message}`);
  return (data as string | null) ?? null;
}

/** Membuat akun login, atau mengganti password bila sudah ada. */
async function pasangPassword(db: SupabaseClient, email: string, pw: string) {
  const ada = await authId(db, email);
  const { error } = ada
    ? await db.auth.admin.updateUserById(ada, { password: pw, email_confirm: true })
    : await db.auth.admin.createUser({ email, password: pw, email_confirm: true });
  if (error) throw pesanAuth(error);
}

async function akunDariId(db: SupabaseClient, id: number) {
  const { data, error } = await db
    .from("users")
    .select("id, email_google, peran")
    .eq("id", id)
    .maybeSingle();
  if (error) throw new Gagal(500, error.message);
  if (!data) throw new Gagal(404, "Akun tidak ditemukan.");
  return data as { id: number; email_google: string; peran: string };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    if (req.method !== "POST") throw new Gagal(405, "Gunakan POST.");
    const db = createClient(Deno.env.get("SUPABASE_URL")!, kunciRahasia(), {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // Pemanggil: harus login, email terverifikasi, dan admin.
    const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    if (!jwt) throw new Gagal(401, "Silakan login terlebih dahulu.");
    const { data: masuk, error: galatMasuk } = await db.auth.getUser(jwt);
    const pemanggil = masuk?.user;
    if (galatMasuk || !pemanggil?.email || !pemanggil.email_confirmed_at) {
      throw new Gagal(401, "Sesi login tidak valid. Silakan login ulang.");
    }
    const { data: saya } = await db
      .from("users")
      .select("id, peran, kelas_id")
      .eq("email_google", pemanggil.email.toLowerCase())
      .maybeSingle();
    if (!saya || saya.peran !== "admin") {
      throw new Gagal(403, "Hanya admin kelas yang boleh mengelola akun.");
    }

    const body = (await req.json().catch(() => ({}))) as Record<string, unknown>;

    switch (body.aksi) {
      case "buat": {
        const akun = dataAkun(body);
        const pw = password(body.password);
        const { data: baru, error } = await db
          .from("users")
          .insert({ ...akun, kelas_id: saya.kelas_id })
          .select("id")
          .single();
        if (error) throw pesanDb(error);
        try {
          await pasangPassword(db, akun.email_google, pw);
        } catch (e) {
          // Batalkan baris users agar tidak ada akun setengah jadi.
          await db.from("users").delete().eq("id", baru.id);
          throw e;
        }
        return balas(200, { id: baru.id });
      }

      case "ubah": {
        const id = idAkun(body.id);
        const akun = dataAkun(body);
        const lama = await akunDariId(db, id);
        if (id === saya.id && akun.peran !== "admin") {
          throw new Gagal(400, "Kamu tidak bisa menurunkan peranmu sendiri.");
        }
        const { error } = await db.from("users").update(akun).eq("id", id);
        if (error) throw pesanDb(error);
        if (akun.email_google !== lama.email_google) {
          const ada = await authId(db, lama.email_google);
          if (ada) {
            const { error: e } = await db.auth.admin.updateUserById(ada, {
              email: akun.email_google,
              email_confirm: true,
            });
            if (e) {
              await db.from("users").update({ email_google: lama.email_google }).eq("id", id);
              throw pesanAuth(e);
            }
          }
        }
        return balas(200, { id });
      }

      case "atur_password": {
        const lama = await akunDariId(db, idAkun(body.id));
        await pasangPassword(db, lama.email_google, password(body.password));
        return balas(200, { id: lama.id });
      }

      case "hapus": {
        const id = idAkun(body.id);
        if (id === saya.id) throw new Gagal(400, "Kamu tidak bisa menghapus akunmu sendiri.");
        const lama = await akunDariId(db, id);
        const { error } = await db.from("users").delete().eq("id", id);
        if (error) {
          throw new Gagal(
            409,
            error.code === "23503"
              ? "Akun ini masih tercatat sebagai pembuat tugas atau kas, jadi tidak bisa dihapus."
              : `Gagal menghapus akun: ${error.message}`,
          );
        }
        const ada = await authId(db, lama.email_google);
        if (ada) await db.auth.admin.deleteUser(ada);
        return balas(200, { id });
      }

      default:
        throw new Gagal(400, "Aksi tidak dikenal.");
    }
  } catch (e) {
    if (e instanceof Gagal) return balas(e.status, { pesan: e.message });
    console.error(e);
    return balas(500, { pesan: "Terjadi kesalahan di server." });
  }
});
