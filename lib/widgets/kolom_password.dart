import 'package:flutter/material.dart';

import '../repositories/akun_repository.dart';

/// Kolom password dengan tombol tampilkan/sembunyikan.
class KolomPassword extends StatefulWidget {
  const KolomPassword({
    super.key,
    required this.controller,
    required this.label,
    this.periksaPanjang = true,
    this.cocokDengan,
    this.enabled = true,
    this.autofill = AutofillHints.newPassword,
    this.textInputAction = TextInputAction.next,
  });

  final TextEditingController controller;
  final String label;

  /// Wajib minimal [AkunRepository.panjangPassword] karakter.
  final bool periksaPanjang;

  /// Bila diisi, nilainya harus sama dengan kolom ini (ulangi password).
  final TextEditingController? cocokDengan;
  final bool enabled;
  final String autofill;
  final TextInputAction textInputAction;

  @override
  State<KolomPassword> createState() => _KolomPasswordState();
}

class _KolomPasswordState extends State<KolomPassword> {
  bool _sembunyi = true;

  String? _periksa(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return '${widget.label} wajib diisi';
    if (widget.periksaPanjang && s.length < AkunRepository.panjangPassword) {
      return 'Minimal ${AkunRepository.panjangPassword} karakter';
    }
    if (widget.cocokDengan != null && s != widget.cocokDengan!.text) {
      return 'Password tidak sama';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _sembunyi,
      autofillHints: [widget.autofill],
      textInputAction: widget.textInputAction,
      validator: _periksa,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _sembunyi ? 'Tampilkan password' : 'Sembunyikan password',
          icon: Icon(
            _sembunyi
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _sembunyi = !_sembunyi),
        ),
      ),
    );
  }
}
