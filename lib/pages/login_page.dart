import 'package:flutter/material.dart';

import '../core/errors.dart';
import '../core/theme.dart';
import '../data/backend.dart';
import '../data/demo/demo_backend.dart';
import '../data/supabase/supabase_auth_repository.dart';
import '../widgets/animasi.dart';
import '../widgets/logo.dart';
import '../widgets/umum.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.backend});

  final BackendClassMate backend;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _memproses = false;
  bool _sembunyikanPassword = true;
  String? _galat;
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Widget _labelTombol(String teks) => Text(_memproses ? 'Memproses…' : teks);

  Widget _ikonTombol(IconData ikon) => _memproses
      ? const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
      : Icon(ikon);

  /// Form email + password untuk backend Supabase.
  List<Widget> _formPassword(SupabaseAuthRepository auth) {
    void kirim() =>
        _masuk(() => auth.masukDenganPassword(_email.text, _password.text));
    return [
      TextField(
        controller: _email,
        enabled: !_memproses,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(
          labelText: 'Email',
          prefixIcon: Icon(Icons.mail_outline),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _password,
        enabled: !_memproses,
        obscureText: _sembunyikanPassword,
        autofillHints: const [AutofillHints.password],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => kirim(),
        decoration: InputDecoration(
          labelText: 'Password',
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            tooltip: _sembunyikanPassword
                ? 'Tampilkan password'
                : 'Sembunyikan password',
            icon: Icon(
              _sembunyikanPassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () =>
                setState(() => _sembunyikanPassword = !_sembunyikanPassword),
          ),
        ),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: _memproses ? null : kirim,
        icon: _ikonTombol(Icons.login),
        label: _labelTombol('Masuk'),
      ),
      if (auth.googleTersedia) ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _memproses ? null : () => _masuk(auth.masuk),
          icon: const Icon(Icons.account_circle_outlined),
          label: const Text('Masuk dengan Google'),
        ),
      ],
    ];
  }

  Future<void> _masuk(Future<void> Function() aksi) async {
    setState(() {
      _memproses = true;
      _galat = null;
    });
    try {
      await aksi();
    } on ClassMateException catch (e) {
      if (mounted) setState(() => _galat = e.pesan);
    } catch (e) {
      if (mounted) setState(() => _galat = 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _memproses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final auth = widget.backend.auth;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: MunculMemantul(child: LogoClassMate(ukuran: 88)),
                  ),
                  const SizedBox(height: 20),
                  Muncul(
                    urutan: 1,
                    child: Text(
                      'ClassMate',
                      textAlign: TextAlign.center,
                      style: t.displaySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Muncul(
                    urutan: 2,
                    child: Text(
                      'Absensi, tugas, dan jadwal kuliah kelasmu dalam satu aplikasi.',
                      textAlign: TextAlign.center,
                      style: t.bodyLarge?.copyWith(color: Warna.teksSekunder),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Muncul(
                    urutan: 3,
                    child: Kartu(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Masuk ke akun kelas', style: t.titleMedium),
                          const SizedBox(height: 4),
                          Text(switch (auth) {
                            DemoAuthRepository() =>
                              'Pilih peran untuk mencoba aplikasi.',
                            SupabaseAuthRepository() =>
                              'Gunakan email dan password dari admin kelas.',
                            _ => 'Gunakan akun Google yang terdaftar di data kelas.',
                          }, style: t.bodySmall),
                          const SizedBox(height: 20),
                          if (auth is DemoAuthRepository) ...[
                            const KotakInfo(
                              jenis: JenisStatus.peringatan,
                              ikon: Icons.science_outlined,
                              teks:
                                  'Mode demo: backend belum dikonfigurasi. '
                                  'Data contoh hilang saat aplikasi ditutup.',
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _memproses
                                  ? null
                                  : () => _masuk(
                                      () => auth.masukSebagai(admin: false),
                                    ),
                              icon: const Icon(Icons.person_outline),
                              label: const Text('Masuk sebagai Anggota'),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _memproses
                                  ? null
                                  : () => _masuk(
                                      () => auth.masukSebagai(admin: true),
                                    ),
                              icon: const Icon(
                                Icons.admin_panel_settings_outlined,
                              ),
                              label: const Text('Masuk sebagai Admin'),
                            ),
                          ] else if (auth is SupabaseAuthRepository)
                            ..._formPassword(auth)
                          else
                            FilledButton.icon(
                              onPressed: _memproses
                                  ? null
                                  : () => _masuk(auth.masuk),
                              icon: _ikonTombol(Icons.login),
                              label: _labelTombol('Masuk dengan Google'),
                            ),
                          if (_galat != null) ...[
                            const SizedBox(height: 16),
                            KotakInfo(
                              jenis: JenisStatus.bahaya,
                              ikon: Icons.block,
                              teks: _galat!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (auth is! DemoAuthRepository) ...[
                    const SizedBox(height: 24),
                    Text(
                      auth is SupabaseAuthRepository
                          ? 'Password tidak disimpan di aplikasi. Login diproses oleh Supabase.'
                          : 'ClassMate tidak menyimpan password. Login diproses oleh Google.',
                      textAlign: TextAlign.center,
                      style: t.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
