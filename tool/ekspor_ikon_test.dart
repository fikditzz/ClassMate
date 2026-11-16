// Mengekspor logo (lib/widgets/logo.dart) menjadi ikon aplikasi.
//
// Jalankan setelah mengubah logo:
//   flutter test tool/ekspor_ikon_test.dart
//
// Menulis:
//   - Android: ikon lama + ikon adaptif (latar, tanda, monokrom) per kepadatan
//   - iOS: AppIcon 1024 px (ukuran lain dibuat dari file ini)
//   - Web: favicon dan ikon PWA
//   - assets/logo/logo_512.png untuk dokumentasi
import 'dart:io';
import 'dart:ui' as ui;

import 'package:classmate/widgets/logo.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _tulis(String path, int px, PelukisLogo pelukis) async {
  final perekam = ui.PictureRecorder();
  final kanvas = Canvas(perekam);
  pelukis.paint(kanvas, Size.square(px.toDouble()));
  final gambar = await perekam.endRecording().toImage(px, px);
  final data = await gambar.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  testWidgets('ekspor ikon aplikasi', (tester) async {
    await tester.runAsync(() async {
      const res = 'android/app/src/main/res';
      // Kepadatan Android: ikon lama 48 dp, lapisan adaptif 108 dp.
      const kepadatan = {
        'mdpi': 1.0,
        'hdpi': 1.5,
        'xhdpi': 2.0,
        'xxhdpi': 3.0,
        'xxxhdpi': 4.0,
      };
      // Tanda pada ikon adaptif harus di dalam zona aman 66 dp dari 108 dp.
      const skalaAdaptif = 0.6;

      for (final MapEntry(key: nama, value: k) in kepadatan.entries) {
        final dir = '$res/mipmap-$nama';
        await _tulis(
          '$dir/ic_launcher.png',
          (48 * k).round(),
          const PelukisLogo(),
        );
        await _tulis(
          '$dir/ic_launcher_background.png',
          (108 * k).round(),
          const PelukisLogo(sudutBulat: false, tanda: false),
        );
        await _tulis(
          '$dir/ic_launcher_foreground.png',
          (108 * k).round(),
          const PelukisLogo(latar: false, skalaTanda: skalaAdaptif),
        );
        await _tulis(
          '$dir/ic_launcher_monochrome.png',
          (108 * k).round(),
          const PelukisLogo(
            latar: false,
            skalaTanda: skalaAdaptif,
            monokrom: true,
          ),
        );
      }

      // iOS tidak boleh transparan dan membulatkan sudut sendiri.
      await _tulis(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
        1024,
        const PelukisLogo(sudutBulat: false),
      );
      await _tulis('assets/logo/logo_512.png', 512, const PelukisLogo());

      // Web: favicon, ikon PWA, dan ikon maskable (tanda di zona aman 80%).
      await _tulis('web/favicon.png', 64, const PelukisLogo());
      for (final px in [192, 512]) {
        await _tulis('web/icons/Icon-$px.png', px, const PelukisLogo());
        await _tulis(
          'web/icons/Icon-maskable-$px.png',
          px,
          const PelukisLogo(sudutBulat: false, skalaTanda: 0.72),
        );
      }
    });
  });
}
