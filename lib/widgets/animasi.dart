import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Durasi dan kurva yang dipakai seragam di seluruh aplikasi.
class Gerak {
  static const cepat = Duration(milliseconds: 150);
  static const sedang = Duration(milliseconds: 250);
  static const lambat = Duration(milliseconds: 400);
  static const kurva = Curves.easeOutCubic;
}

/// Konten masuk dengan memudar dan naik sedikit. [urutan] memberi jeda
/// bertingkat untuk item daftar (dibatasi agar daftar panjang tetap cepat).
///
/// Jeda dibuat dengan Interval di dalam satu AnimationController, bukan
/// Timer, sehingga tidak ada timer menggantung saat widget dibuang.
class Muncul extends StatefulWidget {
  const Muncul({
    super.key,
    required this.child,
    this.urutan = 0,
    this.geser = 16,
  });

  final Widget child;
  final int urutan;
  final double geser;

  @override
  State<Muncul> createState() => _MunculState();
}

class _MunculState extends State<Muncul> with SingleTickerProviderStateMixin {
  static const _dasar = 320, _jeda = 45, _maksUrutan = 6;

  late final AnimationController _c;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    final int jeda = _jeda * math.min(widget.urutan, _maksUrutan);
    final total = _dasar + jeda;
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: total),
    )..forward();
    _t = CurvedAnimation(
      parent: _c,
      curve: Interval(jeda / total, 1, curve: Gerak.kurva),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _t.value) * widget.geser),
          child: child,
        ),
      ),
    );
  }
}

/// Isi tab memudar masuk setiap kali tab itu dipilih. State tab tetap
/// dipertahankan (dipakai di dalam IndexedStack).
class TabMemudar extends StatefulWidget {
  const TabMemudar({super.key, required this.aktif, required this.child});

  final bool aktif;
  final Widget child;

  @override
  State<TabMemudar> createState() => _TabMemudarState();
}

class _TabMemudarState extends State<TabMemudar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Gerak.sedang,
    value: widget.aktif ? 1 : 0,
  );

  @override
  void didUpdateWidget(TabMemudar lama) {
    super.didUpdateWidget(lama);
    if (widget.aktif && !lama.aktif) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: _c, curve: Gerak.kurva);
    return FadeTransition(
      opacity: t,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.015),
          end: Offset.zero,
        ).animate(t),
        child: widget.child,
      ),
    );
  }
}

/// Menggoyang [child] ke kiri-kanan setiap [pemicu] berubah (umpan balik
/// untuk input yang salah).
class Goyang extends StatefulWidget {
  const Goyang({super.key, required this.pemicu, required this.child});

  final Object? pemicu;
  final Widget child;

  @override
  State<Goyang> createState() => _GoyangState();
}

class _GoyangState extends State<Goyang> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(Goyang lama) {
    super.didUpdateWidget(lama);
    if (widget.pemicu != lama.pemicu && widget.pemicu != null) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = _c.value;
        final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}

/// Opacity yang berdenyut pelan, untuk skeleton saat memuat.
class Denyut extends StatefulWidget {
  const Denyut({super.key, required this.child});

  final Widget child;

  @override
  State<Denyut> createState() => _DenyutState();
}

class _DenyutState extends State<Denyut> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(
        begin: 0.45,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

/// Mengecil sedikit saat ditekan, memberi rasa "tombol" pada kartu.
class TekanSkala extends StatefulWidget {
  const TekanSkala({super.key, required this.child, this.aktif = true});

  final Widget child;
  final bool aktif;

  @override
  State<TekanSkala> createState() => _TekanSkalaState();
}

class _TekanSkalaState extends State<TekanSkala> {
  bool _ditekan = false;

  void _atur(bool v) {
    if (widget.aktif && _ditekan != v) setState(() => _ditekan = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _atur(true),
      onPointerUp: (_) => _atur(false),
      onPointerCancel: (_) => _atur(false),
      child: AnimatedScale(
        scale: _ditekan ? 0.98 : 1,
        duration: Gerak.cepat,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Membesar dengan pantulan halus saat pertama tampil (ikon sukses, dsb.).
class MunculMemantul extends StatelessWidget {
  const MunculMemantul({super.key, required this.child, this.tunda = 0});

  final Widget child;

  /// Bagian awal animasi (0..1) sebelum mulai membesar.
  final double tunda;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      child: child,
      builder: (context, v, child) {
        final t = tunda == 0 ? v : ((v - tunda) / (1 - tunda)).clamp(0.0, 1.0);
        final skala = Curves.elasticOut.transform(t) * 0.4 + 0.6;
        return Opacity(
          opacity: Curves.easeOut.transform(t),
          child: Transform.scale(scale: t == 0 ? 0.6 : skala, child: child),
        );
      },
    );
  }
}
