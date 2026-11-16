import 'package:flutter/material.dart';

/// Warna logo ClassMate.
class WarnaLogo {
  static const atas = Color(0xFF1AA7B2);
  static const bawah = Color(0xFF0A6670);
  static const tengah = Color(0xFF108894);
  static const mint = Color(0xFF8BF1EC);
}

/// Logo ClassMate: topi wisuda di atas buku terbuka, putih di kotak
/// bergradasi teal, dengan tali dan rumbai mint sebagai aksen.
/// Melambangkan kelas dan perkuliahan di kampus.
///
/// Logo yang sama diekspor menjadi ikon aplikasi oleh
/// `tool/ekspor_ikon_test.dart`, jadi ubah bentuknya hanya di sini.
class LogoClassMate extends StatelessWidget {
  const LogoClassMate({super.key, this.ukuran = 48});

  final double ukuran;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo ClassMate',
      image: true,
      child: CustomPaint(
        size: Size.square(ukuran),
        painter: const PelukisLogo(),
      ),
    );
  }
}

/// Pelukis logo. Opsinya dipakai untuk menghasilkan lapisan ikon adaptif
/// Android (latar dan tanda dipisah) dan ikon monokrom.
class PelukisLogo extends CustomPainter {
  const PelukisLogo({
    this.latar = true,
    this.sudutBulat = true,
    this.tanda = true,
    this.skalaTanda = 1,
    this.monokrom = false,
  });

  /// Gambar kotak bergradasi di belakang.
  final bool latar;

  /// `false` untuk latar penuh tanpa sudut (lapisan latar ikon adaptif, iOS).
  final bool sudutBulat;

  /// Gambar topi wisuda dan buku.
  final bool tanda;

  /// Perbesaran tanda relatif ke ukuran kanvas (ikon adaptif butuh margin).
  final double skalaTanda;

  /// Semua bagian tanda putih polos (ikon bertema Android 13+).
  final bool monokrom;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final kotak = Offset.zero & Size.square(s);

    if (latar) {
      final cat = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [WarnaLogo.atas, WarnaLogo.bawah],
        ).createShader(kotak);
      if (sudutBulat) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(kotak, Radius.circular(s * 0.27)),
          cat,
        );
      } else {
        canvas.drawRect(kotak, cat);
      }
      // Kilau lembut di kiri atas memberi kedalaman.
      canvas.save();
      if (sudutBulat) {
        canvas.clipRRect(
          RRect.fromRectAndRadius(kotak, Radius.circular(s * 0.27)),
        );
      }
      canvas.drawCircle(
        Offset(s * 0.18, s * 0.12),
        s * 0.55,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromCircle(
                  center: Offset(s * 0.18, s * 0.12),
                  radius: s * 0.55,
                ),
              ),
      );
      canvas.restore();
    }

    if (!tanda) return;

    // Tanda digambar dalam koordinat 0..1, diskalakan dari tengah.
    // Lapisan terpisah agar BlendMode.clear hanya melubangi tanda, bukan latar.
    canvas.saveLayer(kotak, Paint());
    canvas.translate(s / 2, s / 2);
    canvas.scale(s * skalaTanda);
    canvas.translate(-0.5, -0.5);

    final putih = Paint()..color = Colors.white;
    final aksen = Paint()..color = monokrom ? Colors.white : WarnaLogo.mint;
    Paint pemotong(double tebal) => Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = tebal
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // --- Buku terbuka: dua halaman melengkung bertemu di punggung buku.
    final halamanKiri = Path()
      ..moveTo(0.5, 0.86)
      ..quadraticBezierTo(0.34, 0.77, 0.15, 0.81)
      ..lineTo(0.15, 0.63)
      ..quadraticBezierTo(0.34, 0.59, 0.5, 0.68)
      ..close();
    final halamanKanan = Path()
      ..moveTo(0.5, 0.86)
      ..quadraticBezierTo(0.66, 0.77, 0.85, 0.81)
      ..lineTo(0.85, 0.63)
      ..quadraticBezierTo(0.66, 0.59, 0.5, 0.68)
      ..close();
    for (final h in [halamanKiri, halamanKanan]) {
      canvas.drawPath(
        h,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      // Sudut halaman sedikit membulat.
      canvas.drawPath(
        h,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.03
          ..strokeJoin = StrokeJoin.round,
      );
    }
    // Punggung buku: celah tipis di tengah memisahkan dua halaman.
    canvas.drawLine(
      const Offset(0.5, 0.66),
      const Offset(0.5, 0.88),
      pemotong(0.028),
    );

    // --- Topi wisuda: pita kepala, lalu papan belah ketupat di atasnya.
    final pita = Path()
      ..moveTo(0.29, 0.36)
      ..lineTo(0.29, 0.50)
      ..quadraticBezierTo(0.5, 0.60, 0.71, 0.50)
      ..lineTo(0.71, 0.36)
      ..close();
    canvas.drawPath(pita, putih);

    final papan = Path()
      ..moveTo(0.5, 0.15)
      ..lineTo(0.88, 0.31)
      ..lineTo(0.5, 0.47)
      ..lineTo(0.12, 0.31)
      ..close();
    // Celah di bawah papan agar papan dan pita terbaca sebagai dua bagian.
    canvas.drawPath(papan, pemotong(0.05));
    canvas.drawPath(papan, putih);
    canvas.drawPath(
      papan,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.03
        ..strokeJoin = StrokeJoin.round,
    );

    // --- Tali dan rumbai (aksen mint): dari kancing di tengah papan ke tepi
    // kanan, lalu menjuntai turun.
    final tali = Path()
      ..moveTo(0.5, 0.31)
      ..lineTo(0.79, 0.345)
      ..lineTo(0.79, 0.49);
    if (!monokrom) {
      // Di ikon monokrom tali menyatu dengan papan, jadi tidak perlu celah.
      canvas.drawPath(tali, pemotong(0.07));
    }
    canvas.drawPath(
      tali,
      Paint()
        ..color = aksen.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.032
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(const Offset(0.5, 0.31), 0.035, aksen);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(0.762, 0.47, 0.818, 0.575),
        const Radius.circular(0.022),
      ),
      aksen,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(PelukisLogo old) =>
      old.latar != latar ||
      old.sudutBulat != sudutBulat ||
      old.tanda != tanda ||
      old.skalaTanda != skalaTanda ||
      old.monokrom != monokrom;
}
