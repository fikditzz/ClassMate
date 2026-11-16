import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme.dart';
import 'data/backend.dart';
import 'models/pengguna.dart';
import 'pages/home_shell.dart';
import 'pages/login_page.dart';
import 'widgets/animasi.dart';
import 'widgets/logo.dart';

class ClassMateApp extends StatelessWidget {
  const ClassMateApp({super.key, required this.backend, this.fontInter = true});

  final BackendClassMate backend;

  /// Dimatikan di tes agar font tidak diunduh.
  final bool fontInter;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClassMate',
      debugShowCheckedModeBanner: false,
      theme: TemaClassMate.terang(fontInter: fontInter),
      themeMode: ThemeMode.light,
      locale: const Locale('id'),
      supportedLocales: const [Locale('id'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Ikut ukuran font sistem untuk aksesibilitas, tetapi dibatasi agar
      // tata letak kartu tidak rusak di pengaturan font sangat besar.
      builder: (context, child) =>
          MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: child!),
      home: AuthGate(backend: backend),
    );
  }
}

/// Menampilkan halaman login atau aplikasi utama sesuai status login.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.backend});

  final BackendClassMate backend;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<Pengguna?> _pengguna =
      widget.backend.auth.perubahanPengguna;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Pengguna?>(
      stream: _pengguna,
      builder: (context, snap) {
        final Widget layar;
        final pengguna = snap.data;
        if (snap.connectionState == ConnectionState.waiting) {
          layar = const _LayarMuat(key: ValueKey('muat'));
        } else if (pengguna == null) {
          layar = LoginPage(
            key: const ValueKey('login'),
            backend: widget.backend,
          );
        } else {
          layar = HomeShell(
            key: ValueKey(pengguna.uid),
            pengguna: pengguna,
            backend: widget.backend,
          );
        }
        // Login, beranda, dan keluar berpindah dengan memudar, bukan terpotong.
        return AnimatedSwitcher(
          duration: Gerak.lambat,
          switchInCurve: Gerak.kurva,
          switchOutCurve: Curves.easeIn,
          child: layar,
        );
      },
    );
  }
}

/// Layar pembuka saat status login sedang diperiksa.
class _LayarMuat extends StatelessWidget {
  const _LayarMuat({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MunculMemantul(child: LogoClassMate(ukuran: 88)),
            const SizedBox(height: 16),
            Text(
              'ClassMate',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
