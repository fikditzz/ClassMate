import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../widgets/animasi.dart';
import '../widgets/umum.dart';
import 'ganti_password.dart';
import 'kelola_akun_page.dart';
import 'kelola_mata_kuliah_page.dart';

class ProfilPage extends StatelessWidget {
  const ProfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = scope.pengguna;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: appBarClassMate(context, judul: 'Profil Saya', avatar: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (final (i, w) in <Widget>[
            Kartu(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  AvatarInisial(p.nama, ukuran: 88),
                  const SizedBox(height: 16),
                  Text(
                    p.nama,
                    style: t.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${p.username}',
                    style: t.bodyMedium?.copyWith(color: Warna.teksSekunder),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ChipStatus(
                        p.labelPeran,
                        jenis: p.isAdmin
                            ? JenisStatus.info
                            : JenisStatus.netral,
                        ikon: p.isAdmin
                            ? Icons.admin_panel_settings_outlined
                            : Icons.person_outline,
                      ),
                      if (p.kelasId != null)
                        ChipStatus(
                          'Kelas ${p.kelasId}',
                          jenis: JenisStatus.netral,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const LabelAtas('Akun', warna: Warna.teksSekunder),
            const SizedBox(height: 8),
            Kartu(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _Baris(
                    ikon: Icons.mail_outline,
                    judul: 'Email',
                    isi: p.email,
                  ),
                  const Divider(indent: 72),
                  _Baris(
                    ikon: Icons.verified_user_outlined,
                    judul: 'Hak akses',
                    isi: p.bolehKelolaAkun
                        ? 'Mengelola akun, mata kuliah, jadwal, sesi absensi, '
                              'dan tugas'
                        : p.isAdmin
                        ? 'Mengelola mata kuliah, jadwal, sesi absensi, dan tugas'
                        : 'Absen, mengumpulkan tugas, melihat jadwal',
                  ),
                  const Divider(indent: 72),
                  _Baris(
                    ikon: Icons.password_outlined,
                    judul: 'Ganti password',
                    isi: 'Perlu password lama',
                    onTap: () => bukaGantiPassword(context),
                  ),
                ],
              ),
            ),
            if (p.isAdmin) ...[
              const SizedBox(height: 24),
              const LabelAtas('Administrasi', warna: Warna.teksSekunder),
              const SizedBox(height: 8),
              Kartu(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    if (p.bolehKelolaAkun) ...[
                      _Baris(
                        ikon: Icons.manage_accounts_outlined,
                        judul: 'Kelola akun',
                        isi: 'Tambah anggota, ubah peran, atur password',
                        onTap: () => bukaKelolaAkun(context),
                      ),
                      const Divider(indent: 72),
                    ],
                    _Baris(
                      ikon: Icons.menu_book_outlined,
                      judul: 'Kelola mata kuliah',
                      isi: 'Nama, kode, SKS, dan dosen',
                      onTap: () => bukaKelolaMataKuliah(context),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            const LabelAtas('Aplikasi', warna: Warna.teksSekunder),
            const SizedBox(height: 8),
            Kartu(
              padding: EdgeInsets.zero,
              child: _Baris(
                ikon: scope.modeDemo
                    ? Icons.science_outlined
                    : Icons.cloud_done_outlined,
                judul: 'Sumber data',
                isi: scope.modeDemo
                    ? 'Mode demo (data contoh di perangkat)'
                    : 'Supabase (tersinkron langsung)',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Warna.bahayaMuda,
                foregroundColor: Warna.bahaya,
              ),
              onPressed: () async {
                final ya = await konfirmasi(
                  context,
                  ikon: Icons.logout,
                  judul: 'Keluar dari ClassMate?',
                  pesan:
                      'Kamu perlu masuk lagi dengan email dan password untuk '
                      'absen dan melihat tugas.',
                  tombolYa: 'Keluar',
                  bahaya: true,
                );
                if (ya) await scope.auth.keluar();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Keluar dari Akun'),
            ),
            const SizedBox(height: 16),
            Text(
              'ClassMate v0.1.0',
              textAlign: TextAlign.center,
              style: t.bodySmall,
            ),
          ].indexed)
            Muncul(urutan: i, child: w),
        ],
      ),
    );
  }
}

class _Baris extends StatelessWidget {
  const _Baris({
    required this.ikon,
    required this.judul,
    required this.isi,
    this.onTap,
  });

  final IconData ikon;
  final String judul;
  final String isi;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            IkonKotak(ikon),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(judul, style: t.titleSmall),
                  const SizedBox(height: 2),
                  Text(isi, style: t.bodySmall),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: Warna.teksSekunder),
          ],
        ),
      ),
    );
  }
}
