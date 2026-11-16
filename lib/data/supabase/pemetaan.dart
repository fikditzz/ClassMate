// Mengubah baris tabel Supabase menjadi model aplikasi dan sebaliknya.
//
// Skema Supabase memakai ID bigint, nama hari ("Senin"), kolom `time`
// ("07:30:00"), dan sesi absen berupa tanggal + jam WITA. Model aplikasi
// memakai ID String, hari 1-7, jam "HH:mm", dan DateTime.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors.dart';
import '../../models/akun.dart';
import '../../models/jadwal.dart';
import '../../models/perubahan_jadwal.dart';
import '../../models/kehadiran.dart';
import '../../models/konversi.dart';
import '../../models/mata_kuliah.dart';
import '../../models/pengumpulan.dart';
import '../../models/sesi_absensi.dart';
import '../../models/tugas.dart';

/// WITA = UTC+8, tanpa pergeseran musim panas.
const _selisihWita = Duration(hours: 8);

String _dua(int n) => n.toString().padLeft(2, '0');

/// Tanggal "2026-11-15" dan jam "07:30:00" dalam WITA menjadi waktu lokal
/// perangkat.
DateTime dariWita(String tanggal, String jam) {
  final t = DateTime.parse(tanggal);
  final b = jam.split(':');
  final detik = b.length > 2 ? int.parse(b[2].split('.').first) : 0;
  return DateTime.utc(
    t.year,
    t.month,
    t.day,
    int.parse(b[0]),
    int.parse(b[1]),
    detik,
  ).subtract(_selisihWita).toLocal();
}

/// Waktu apa pun menjadi tanggal ("2026-11-15") dan jam ("07:30:00") WITA.
({String tanggal, String jam}) keWita(DateTime waktu) {
  final w = waktu.toUtc().add(_selisihWita);
  return (
    tanggal:
        '${w.year.toString().padLeft(4, '0')}-${_dua(w.month)}-${_dua(w.day)}',
    jam: '${_dua(w.hour)}:${_dua(w.minute)}:${_dua(w.second)}',
  );
}

/// "07:30:00" menjadi "07:30".
String jamPendek(Object? jam) {
  final s = '${jam ?? '00:00'}';
  return s.length > 5 ? s.substring(0, 5) : s;
}

/// "Senin" menjadi 1 ... "Minggu" menjadi 7.
int hariDariNama(Object? nama) {
  final i = Jadwal.daftarHari.indexOf('$nama');
  return i < 0 ? 1 : i + 1;
}

String namaHari(int hari) => Jadwal.daftarHari[hari - 1];

int keId(String id) => int.parse(id);

MataKuliah mataKuliahDari(Map<String, dynamic> r) => MataKuliah(
  id: '${r['id']}',
  nama: (r['nama'] as String?) ?? '${r['id']}',
  kelasId: r['kelas_id']?.toString(),
  kode: (r['kode'] as String?) ?? '',
  sks: (r['sks'] as num?)?.toInt() ?? 0,
  dosen: [for (final x in (r['dosen'] as List?) ?? const []) '$x'],
);

Map<String, dynamic> mataKuliahKeBaris(MataKuliah m) => {
  'nama': m.nama.trim(),
  'kode': m.kode.trim().isEmpty ? null : m.kode.trim(),
  'sks': m.sks,
  'dosen': [
    for (final d in m.dosen)
      if (d.trim().isNotEmpty) d.trim(),
  ],
};

/// Tanggal kalender (tanpa jam) sebagai "2026-11-16".
String tanggalIso(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${_dua(t.month)}-${_dua(t.day)}';

DateTime? _tanggalDari(Object? nilai) =>
    nilai == null ? null : tanggalSaja(DateTime.parse('$nilai'));

PerubahanJadwal perubahanDari(Map<String, dynamic> r) => PerubahanJadwal(
  id: '${r['id']}',
  jenis: JenisPerubahan.values.byName('${r['jenis']}'),
  mataKuliahId: '${r['mata_kuliah_id']}',
  jadwalId: r['jadwal_id']?.toString(),
  tanggalAsal: _tanggalDari(r['tanggal_asal']),
  tanggal: _tanggalDari(r['tanggal']),
  jamMulai: r['jam_mulai'] == null ? null : jamPendek(r['jam_mulai']),
  jamSelesai: r['jam_selesai'] == null ? null : jamPendek(r['jam_selesai']),
  ruang: (r['ruang'] as String?) ?? '',
  keterangan: (r['keterangan'] as String?) ?? '',
);

Map<String, dynamic> perubahanKeBaris(PerubahanJadwal p) {
  final libur = p.jenis == JenisPerubahan.libur;
  return {
    'jenis': p.jenis.name,
    'mata_kuliah_id': keId(p.mataKuliahId),
    'jadwal_id': p.jadwalId == null ? null : keId(p.jadwalId!),
    'tanggal_asal': p.tanggalAsal == null ? null : tanggalIso(p.tanggalAsal!),
    'tanggal': libur || p.tanggal == null ? null : tanggalIso(p.tanggal!),
    'jam_mulai': libur ? null : p.jamMulai,
    'jam_selesai': libur ? null : p.jamSelesai,
    'ruang': libur || p.ruang.trim().isEmpty ? null : p.ruang.trim(),
    'keterangan': p.keterangan.trim().isEmpty ? null : p.keterangan.trim(),
  };
}

Akun akunDari(Map<String, dynamic> r) => Akun(
  id: '${r['id']}',
  nama: (r['nama'] as String?) ?? '',
  username: (r['username'] as String?) ?? '',
  email: (r['email'] as String?) ?? '',
  peran: (r['peran'] as String?) ?? 'mahasiswa',
  punyaLogin: r['punya_login'] == true,
  loginTerakhir: r['login_terakhir'] == null
      ? null
      : keDateTime(r['login_terakhir']),
);

Jadwal jadwalDari(Map<String, dynamic> r) => Jadwal(
  id: '${r['id']}',
  mataKuliahId: '${r['mata_kuliah_id']}',
  hari: hariDariNama(r['hari']),
  jamMulai: jamPendek(r['jam_mulai']),
  jamSelesai: jamPendek(r['jam_selesai']),
  ruang: (r['ruang'] as String?) ?? '',
);

Map<String, dynamic> jadwalKeBaris(Jadwal j) => {
  'mata_kuliah_id': keId(j.mataKuliahId),
  'hari': namaHari(j.hari),
  'jam_mulai': j.jamMulai,
  'jam_selesai': j.jamSelesai,
  'ruang': j.ruang.isEmpty ? null : j.ruang,
};

SesiAbsensi sesiDari(Map<String, dynamic> r) => SesiAbsensi(
  id: '${r['id']}',
  mataKuliahId: '${r['mata_kuliah_id']}',
  mulai: dariWita('${r['tanggal']}', '${r['jam_mulai']}'),
  berakhir: dariWita('${r['tanggal']}', '${r['jam_selesai']}'),
  // Skema memakai aktif/ditutup/dibatalkan; aplikasi hanya buka/tutup.
  status: r['status'] == 'aktif' ? 'buka' : 'tutup',
);

Tugas tugasDari(Map<String, dynamic> r) => Tugas(
  id: '${r['id']}',
  mataKuliahId: '${r['mata_kuliah_id']}',
  judul: (r['judul'] as String?) ?? '(tanpa judul)',
  deskripsi: (r['deskripsi'] as String?) ?? '',
  tenggat: keDateTime(r['tenggat']),
  dibuatOleh: '${r['dibuat_oleh'] ?? ''}',
);

Kehadiran kehadiranDari(Map<String, dynamic> r, String email) => Kehadiran(
  sesiId: '${r['sesi_id']}',
  uid: '${r['user_id']}',
  email: email,
  waktuAbsen: keDateTime(r['waktu_absen']),
);

Pengumpulan pengumpulanDari(Map<String, dynamic> r, String email) =>
    Pengumpulan(
      tugasId: '${r['tugas_id']}',
      uid: '${r['user_id']}',
      email: email,
      driveFileId: (r['drive_file_id'] as String?) ?? '',
      driveUrl: (r['drive_url'] as String?) ?? '',
      namaFile: (r['nama_file'] as String?) ?? '',
      ukuran: (r['ukuran'] as num?)?.toInt() ?? 0,
      waktuUpload: keDateTime(r['waktu_upload']),
    );

/// Mengubah kegagalan Supabase menjadi pesan yang aman ditampilkan.
ClassMateException pesanGagal(Object e, String awalan) {
  if (e is ClassMateException) return e;
  if (e is PostgrestException) {
    return ClassMateException(switch (e.code) {
      '42501' => '$awalan: kamu tidak punya izin.',
      '23505' => '$awalan: data yang sama sudah ada.',
      '23503' => '$awalan: data ini masih dipakai data lain.',
      _ when e.message == 'tanggal_asal_bukan_hari_jadwal' =>
        '$awalan: tanggal tidak sesuai hari jadwalnya.',
      _ => '$awalan: ${e.message}',
    });
  }
  if (e is FunctionException) {
    final d = e.details;
    final pesan = d is Map ? d['pesan'] : null;
    return ClassMateException(
      pesan is String ? pesan : '$awalan (kode ${e.status}).',
    );
  }
  if (e is AuthException) return ClassMateException('$awalan: ${e.message}');
  return ClassMateException(
    '$awalan. Periksa koneksi internet lalu coba lagi.',
  );
}

/// Mencari email pengguna dari ID tabel `users` untuk rekap admin dan dosen.
/// Hasilnya disimpan agar tiap perubahan realtime tidak memicu query baru.
class PencariEmail {
  PencariEmail(this._db);

  final SupabaseClient _db;
  final _simpanan = <String, String>{};

  Future<String Function(String id)> untuk(Iterable<String> ids) async {
    final kurang = ids.where((id) => !_simpanan.containsKey(id)).toSet();
    if (kurang.isNotEmpty) {
      final baris = await _db.from('users').select('id, email_google').inFilter(
        'id',
        [for (final id in kurang) keId(id)],
      );
      for (final r in baris) {
        _simpanan['${r['id']}'] = '${r['email_google']}'.toLowerCase();
      }
    }
    return (id) => _simpanan[id] ?? 'pengguna #$id';
  }
}
