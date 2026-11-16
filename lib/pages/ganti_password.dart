import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/errors.dart';
import '../repositories/akun_repository.dart';
import '../widgets/kolom_password.dart';
import '../widgets/umum.dart';

/// Lembar ganti password untuk akun yang sedang login. Password lama wajib
/// diisi; bila lupa, admin kelas bisa mengatur password baru.
void bukaGantiPassword(BuildContext context) {
  final scope = AppScope.baca(context);
  bukaLembar<void>(
    context,
    judul: 'Ganti Password',
    subjudul:
        'Masukkan password lama, lalu password baru minimal '
        '${AkunRepository.panjangPassword} karakter. Lupa password lama? '
        'Minta admin kelas mengatur password baru.',
    isi: (_) => _FormGantiPassword(scope: scope),
  );
}

class _FormGantiPassword extends StatefulWidget {
  const _FormGantiPassword({required this.scope});

  final AppScope scope;

  @override
  State<_FormGantiPassword> createState() => _FormGantiPasswordState();
}

class _FormGantiPasswordState extends State<_FormGantiPassword> {
  final _kunci = GlobalKey<FormState>();
  final _lama = TextEditingController();
  final _baru = TextEditingController();
  final _ulang = TextEditingController();
  bool _memproses = false;
  String? _galat;

  @override
  void dispose() {
    _lama.dispose();
    _baru.dispose();
    _ulang.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_kunci.currentState!.validate()) return;
    setState(() {
      _memproses = true;
      _galat = null;
    });
    try {
      await widget.scope.auth.gantiPassword(_lama.text, _baru.text);
      if (mounted) {
        Navigator.pop(context);
        tampilkanPesan(context, 'Password berhasil diganti.');
      }
    } on ClassMateException catch (e) {
      if (mounted) setState(() => _galat = e.pesan);
    } catch (e) {
      if (mounted) setState(() => _galat = 'Gagal mengganti password: $e');
    } finally {
      if (mounted) setState(() => _memproses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _kunci,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KolomPassword(
              controller: _lama,
              label: 'Password lama',
              periksaPanjang: false,
              autofill: AutofillHints.password,
              enabled: !_memproses,
            ),
            const SizedBox(height: 12),
            KolomPassword(
              controller: _baru,
              label: 'Password baru',
              enabled: !_memproses,
            ),
            const SizedBox(height: 12),
            KolomPassword(
              controller: _ulang,
              label: 'Ulangi password baru',
              cocokDengan: _baru,
              enabled: !_memproses,
              textInputAction: TextInputAction.done,
            ),
            if (_galat != null) ...[
              const SizedBox(height: 16),
              KotakInfo(
                jenis: JenisStatus.bahaya,
                ikon: Icons.error_outline,
                teks: _galat!,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _memproses ? null : _simpan,
              child: Text(_memproses ? 'Menyimpan…' : 'Simpan Password'),
            ),
          ],
        ),
      ),
    );
  }
}
