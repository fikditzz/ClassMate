import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'animasi.dart';

/// Lingkaran yang tergambar menyapu, lalu tanda centang yang ditarik dari
/// kiri ke kanan. Untuk konfirmasi keberhasilan (misalnya presensi).
class CentangDigambar extends StatefulWidget {
  const CentangDigambar({
    super.key,
    this.ukuran = 64,
    required this.warna,
    this.tebal = 5,
  });

  final double ukuran;
  final Color warna;
  final double tebal;

  @override
  State<CentangDigambar> createState() => _CentangDigambarState();
}

class _CentangDigambarState extends State<CentangDigambar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  // Lingkaran di 0–55% waktu, centang di 45–100%: sedikit tumpang tindih
  // agar gerakannya terasa satu tarikan.
  late final _lingkaran = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.55, curve: Curves.easeInOutCubic),
  );
  late final _centang = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.45, 1, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _lingkaran.dispose();
    _centang.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Berhasil',
      child: CustomPaint(
        size: Size.square(widget.ukuran),
        painter: _PelukisCentang(
          lingkaran: _lingkaran,
          centang: _centang,
          warna: widget.warna,
          tebal: widget.tebal,
        ),
      ),
    );
  }
}

class _PelukisCentang extends CustomPainter {
  _PelukisCentang({
    required this.lingkaran,
    required this.centang,
    required this.warna,
    required this.tebal,
  }) : super(repaint: Listenable.merge([lingkaran, centang]));

  final Animation<double> lingkaran;
  final Animation<double> centang;
  final Color warna;
  final double tebal;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final cat = Paint()
      ..color = warna
      ..style = PaintingStyle.stroke
      ..strokeWidth = tebal
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final kotak = Rect.fromLTWH(tebal / 2, tebal / 2, s - tebal, s - tebal);
    canvas.drawArc(
      kotak,
      -math.pi / 2,
      2 * math.pi * lingkaran.value,
      false,
      cat,
    );

    if (centang.value == 0) return;
    final jalur = Path()
      ..moveTo(s * 0.28, s * 0.52)
      ..lineTo(s * 0.44, s * 0.67)
      ..lineTo(s * 0.73, s * 0.37);
    for (final m in jalur.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * centang.value), cat);
    }
  }

  @override
  bool shouldRepaint(_PelukisCentang old) =>
      old.warna != warna || old.tebal != tebal;
}

/// Pita cahaya lembut yang menyapu [child] berulang-ulang, untuk skeleton
/// saat data dimuat.
class Kilau extends StatefulWidget {
  const Kilau({super.key, required this.child});

  final Widget child;

  @override
  State<Kilau> createState() => _KilauState();
}

class _KilauState extends State<Kilau> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

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
        // Pita bergerak dari luar kiri ke luar kanan.
        final x = -1.5 + 3.0 * Curves.easeInOutSine.transform(_c.value);
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(x - 0.6, -0.3),
            end: Alignment(x + 0.6, 0.3),
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.65),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0.2, 0.5, 0.8],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// Angka yang bergulir naik (atau turun) saat nilainya berubah, seperti
/// odometer kecil. Nilai pertama tampil tanpa animasi.
class AngkaBerganti extends StatefulWidget {
  const AngkaBerganti(this.nilai, {super.key, this.style});

  final int nilai;
  final TextStyle? style;

  @override
  State<AngkaBerganti> createState() => _AngkaBergantiState();
}

class _AngkaBergantiState extends State<AngkaBerganti> {
  bool _naik = true;

  @override
  void didUpdateWidget(AngkaBerganti lama) {
    super.didUpdateWidget(lama);
    if (lama.nilai != widget.nilai) _naik = widget.nilai > lama.nilai;
  }

  @override
  Widget build(BuildContext context) {
    final arah = _naik ? 1.0 : -1.0;
    return ClipRect(
      child: AnimatedSwitcher(
        duration: Gerak.sedang,
        switchInCurve: Gerak.kurva,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (anak, a) {
          // Angka baru masuk dari bawah saat naik (dari atas saat turun);
          // angka lama keluar ke arah sebaliknya.
          final baru = anak.key == ValueKey(widget.nilai);
          final mulai = Offset(0, baru ? 0.6 * arah : -0.6 * arah);
          return FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: mulai, end: Offset.zero).animate(a),
              child: anak,
            ),
          );
        },
        layoutBuilder: (sekarang, sebelumnya) => Stack(
          alignment: Alignment.center,
          children: [...sebelumnya, ?sekarang],
        ),
        child: Text(
          '${widget.nilai}',
          key: ValueKey(widget.nilai),
          style: (widget.style ?? const TextStyle()).copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Ikon yang "pop" (mengecil lalu memantul ke ukuran normal) saat pertama
/// dibangun. Dipakai sebagai ikon tab terpilih.
class IkonMuncul extends StatelessWidget {
  const IkonMuncul(this.ikon, {super.key});

  final IconData ikon;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.7, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: Icon(ikon),
    );
  }
}

/// Judul yang "terbang" dari kartu daftar ke judul halaman detail (Hero),
/// dengan ukuran huruf berpindah mulus di antara kedua gaya.
class JudulHero extends StatelessWidget {
  const JudulHero({
    super.key,
    required this.tag,
    required this.teks,
    required this.style,
    this.maxLines,
  });

  final Object tag;
  final String teks;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      flightShuttleBuilder: (context, animasi, arah, dariCtx, keCtx) {
        final dari = (dariCtx.widget as Hero).child as _TeksHero;
        final ke = (keCtx.widget as Hero).child as _TeksHero;
        // Nilai animasi 1 = halaman yang dibuka (detail), baik saat
        // membuka (0→1) maupun menutup (1→0).
        final daftar = arah == HeroFlightDirection.push ? dari : ke;
        final detail = arah == HeroFlightDirection.push ? ke : dari;
        return AnimatedBuilder(
          animation: animasi,
          builder: (context, _) => _TeksHero(
            teks: teks,
            style: TextStyle.lerp(daftar.style, detail.style, animasi.value),
          ),
        );
      },
      child: _TeksHero(teks: teks, style: style, maxLines: maxLines),
    );
  }
}

class _TeksHero extends StatelessWidget {
  const _TeksHero({required this.teks, required this.style, this.maxLines});

  final String teks;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    // Material transparan mencegah garis bawah kuning saat teks melayang
    // di overlay tanpa DefaultTextStyle.
    return Material(
      type: MaterialType.transparency,
      child: Text(
        teks,
        style: style,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
      ),
    );
  }
}

/// Nominal Rupiah yang menghitung naik ke nilainya, lalu bergeser mulus
/// setiap kali nilainya berubah.
class RupiahBerjalan extends StatelessWidget {
  const RupiahBerjalan(this.nilai, {super.key, this.style, this.format});

  final int nilai;
  final TextStyle? style;

  /// Pengubah angka ke teks, misalnya formatRupiah.
  final String Function(int)? format;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: nilai.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        (format ?? (n) => '$n')(v.round()),
        style: (style ?? const TextStyle()).copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Cincin persentase yang terisi beranimasi, dengan angka di tengah.
class CincinPersen extends StatelessWidget {
  const CincinPersen({
    super.key,
    required this.nilai,
    required this.warna,
    required this.latar,
    this.ukuran = 120,
    this.tebal = 12,
    this.style,
  });

  /// 0..1
  final double nilai;
  final Color warna;
  final Color latar;
  final double ukuran;
  final double tebal;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: nilai.clamp(0, 1).toDouble()),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox.square(
        dimension: ukuran,
        child: CustomPaint(
          painter: _PelukisCincin(
            nilai: v,
            warna: warna,
            latar: latar,
            tebal: tebal,
          ),
          child: Center(
            child: Text(
              '${(v * 100).round()}%',
              style: (style ?? const TextStyle()).copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PelukisCincin extends CustomPainter {
  _PelukisCincin({
    required this.nilai,
    required this.warna,
    required this.latar,
    required this.tebal,
  });

  final double nilai;
  final Color warna;
  final Color latar;
  final double tebal;

  @override
  void paint(Canvas canvas, Size size) {
    final kotak = (Offset.zero & size).deflate(tebal / 2);
    final cat = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = tebal
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(kotak, 0, 2 * math.pi, false, cat..color = latar);
    if (nilai > 0) {
      canvas.drawArc(
        kotak,
        -math.pi / 2,
        2 * math.pi * nilai,
        false,
        cat..color = warna,
      );
    }
  }

  @override
  bool shouldRepaint(_PelukisCincin old) =>
      old.nilai != nilai || old.warna != warna || old.latar != latar;
}
