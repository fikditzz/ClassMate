import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../data/backend.dart';
import '../models/mata_kuliah.dart';
import '../models/pengguna.dart';
import 'absensi_page.dart';
import 'dashboard_page.dart';
import 'jadwal_page.dart';
import '../widgets/animasi.dart';
import 'profil_page.dart';
import 'tugas_page.dart';

/// Kerangka utama setelah login: bottom navigation dan lima tab.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.pengguna, required this.backend});

  final Pengguna pengguna;
  final BackendClassMate backend;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final RepositoriPengguna _repo = widget.backend.buatRepositori(
    widget.pengguna,
  );
  late final Stream<List<MataKuliah>> _mataKuliah = _repo.jadwal.mataKuliah();
  int _tab = 0;

  static const _halaman = [
    DashboardPage(),
    AbsensiPage(),
    TugasPage(),
    JadwalPage(),
    ProfilPage(),
  ];

  void _bukaTab(int i) {
    if (i == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MataKuliah>>(
      stream: _mataKuliah,
      builder: (context, snap) {
        return AppScope(
          pengguna: widget.pengguna,
          auth: widget.backend.auth,
          repo: _repo,
          mataKuliah: snap.data ?? const [],
          modeDemo: widget.backend.modeDemo,
          bukaTab: _bukaTab,
          child: Scaffold(
            // IndexedStack menjaga state (dan langganan stream) tiap tab;
            // TabMemudar memberi transisi halus saat berpindah.
            body: IndexedStack(
              index: _tab,
              children: [
                for (final (i, halaman) in _halaman.indexed)
                  TabMemudar(aktif: i == _tab, child: halaman),
              ],
            ),
            bottomNavigationBar: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Warna.garis)),
              ),
              child: NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: _bukaTab,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Beranda',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.how_to_reg_outlined),
                    selectedIcon: Icon(Icons.how_to_reg),
                    label: 'Absensi',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.assignment_outlined),
                    selectedIcon: Icon(Icons.assignment),
                    label: 'Tugas',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month),
                    label: 'Jadwal',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Profil',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
