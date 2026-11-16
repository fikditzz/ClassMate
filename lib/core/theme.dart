import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:google_fonts/google_fonts.dart';

/// Token warna dari desain "Academic Streamline Teal" (layar Stitch
/// Dashboard 2B dan Absensi 3A/3B). Varian biru sebelumnya:
/// primer 1A73E8, primerMuda E8F0FE, latar F8F9FA.
class Warna {
  static const primer = Color(0xFF108894);
  static const primerMuda = Color(0xFFE0F2F3);
  static const latar = Color(0xFFF2FBFF);
  static const permukaan = Color(0xFFFFFFFF);
  static const garis = Color(0xFFD3E2E4);
  static const teks = Color(0xFF04222B);
  static const teksSekunder = Color(0xFF3E494A);

  static const sukses = Color(0xFF1E8E3E);
  static const suksesMuda = Color(0xFFE6F4EA);
  static const bahaya = Color(0xFFD93025);
  static const bahayaMuda = Color(0xFFFCE8E6);
  static const peringatan = Color(0xFFF9AB00);
  static const peringatanMuda = Color(0xFFFEF7E0);
  static const peringatanTeks = Color(0xFFB06000);
  static const netral = Color(0xFF6E797B);
  static const netralMuda = Color(0xFFEAF3F5);
}

/// Bayangan kartu (Surface Elev-1) dan lembar/dialog (Elev-2).
class Bayangan {
  static const elev1 = [
    BoxShadow(color: Color(0x141F1F1F), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A1F1F1F), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const elev2 = [
    BoxShadow(
      color: Color(0x141F1F1F),
      blurRadius: 8,
      spreadRadius: 3,
      offset: Offset(0, 4),
    ),
    BoxShadow(color: Color(0x1F1F1F1F), blurRadius: 3, offset: Offset(0, 1)),
  ];
}

class TemaClassMate {
  /// [fontInter] dimatikan di tes agar tidak mengunduh font dari internet.
  static ThemeData terang({bool fontInter = true}) {
    const skema = ColorScheme(
      brightness: Brightness.light,
      primary: Warna.primer,
      onPrimary: Colors.white,
      primaryContainer: Warna.primerMuda,
      onPrimaryContainer: Warna.primer,
      secondary: Warna.teksSekunder,
      onSecondary: Colors.white,
      secondaryContainer: Warna.netralMuda,
      onSecondaryContainer: Warna.teks,
      tertiary: Warna.sukses,
      onTertiary: Colors.white,
      tertiaryContainer: Warna.suksesMuda,
      onTertiaryContainer: Warna.sukses,
      error: Warna.bahaya,
      onError: Colors.white,
      errorContainer: Warna.bahayaMuda,
      onErrorContainer: Warna.bahaya,
      surface: Warna.permukaan,
      onSurface: Warna.teks,
      onSurfaceVariant: Warna.teksSekunder,
      surfaceContainerLowest: Warna.permukaan,
      surfaceContainerLow: Warna.latar,
      surfaceContainer: Warna.netralMuda,
      surfaceContainerHigh: Color(0xFFDCEDF1),
      surfaceContainerHighest: Color(0xFFD0E5EA),
      outline: Color(0xFF6E797B),
      outlineVariant: Warna.garis,
      inverseSurface: Color(0xFF19343D),
      onInverseSurface: Color(0xFFDDF5FF),
      surfaceTint: Colors.transparent,
    );

    final dasar = _teks(fontInter);
    const sudut12 = BorderRadius.all(Radius.circular(12));
    const sudut16 = BorderRadius.all(Radius.circular(16));

    return ThemeData(
      useMaterial3: true,
      colorScheme: skema,
      textTheme: dasar,
      fontFamily: fontInter ? GoogleFonts.inter().fontFamily : null,
      scaffoldBackgroundColor: Warna.latar,
      appBarTheme: AppBarTheme(
        backgroundColor: Warna.latar,
        foregroundColor: Warna.teks,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0.5,
        shadowColor: Warna.garis,
        centerTitle: false,
        titleSpacing: 16,
        titleTextStyle: dasar.headlineSmall,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Warna.permukaan,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: sudut16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: const RoundedRectangleBorder(borderRadius: sudut12),
          textStyle: dasar.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          foregroundColor: Warna.teks,
          side: const BorderSide(color: Warna.garis),
          shape: const RoundedRectangleBorder(borderRadius: sudut12),
          textStyle: dasar.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: sudut12),
          textStyle: dasar.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Warna.permukaan,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: dasar.bodyMedium?.copyWith(color: Warna.teksSekunder),
        hintStyle: dasar.bodyMedium?.copyWith(color: Warna.teksSekunder),
        border: const OutlineInputBorder(
          borderRadius: sudut12,
          borderSide: BorderSide(color: Warna.garis),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: sudut12,
          borderSide: BorderSide(color: Warna.garis),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: sudut12,
          borderSide: BorderSide(color: Warna.primer, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: sudut12,
          borderSide: BorderSide(color: Warna.bahaya),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        backgroundColor: Warna.permukaan,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Warna.primerMuda,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => dasar.labelMedium?.copyWith(
            color: s.contains(WidgetState.selected)
                ? Warna.primer
                : Warna.teksSekunder,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? Warna.primer
                : Warna.teksSekunder,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: Warna.permukaan,
          selectedBackgroundColor: Warna.primerMuda,
          selectedForegroundColor: Warna.primer,
          side: const BorderSide(color: Warna.garis),
          textStyle: dasar.labelLarge,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Warna.permukaan,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: Warna.garis,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Warna.permukaan,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: sudut16),
        titleTextStyle: dasar.headlineSmall,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Warna.primer,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: sudut16),
      ),
      dividerTheme: const DividerThemeData(color: Warna.garis, space: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Warna.primer,
        linearTrackColor: Warna.netralMuda,
      ),
      // Transisi halaman: fade + geser halus, seragam di semua platform.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: sudut12),
      ),
    );
  }

  /// Skala tipografi dari DESIGN.md (Inter).
  ///
  /// Ukuran dan tinggi baris mengikuti desain. Letter-spacing tidak memakai
  /// nilai bawaan Material (dirancang untuk Roboto): Inter sudah lega di
  /// ukuran kecil dan perlu dirapatkan di ukuran judul.
  static TextTheme _teks(bool inter) {
    const t = Warna.teks;
    TextStyle gaya(
      double ukuran,
      double tinggi, {
      FontWeight tebal = FontWeight.w400,
      double jarak = 0,
      Color? warna = t,
    }) => TextStyle(
      // Tanpa Inter (tes), tetap sebut keluarga font agar gaya yang dipakai
      // langsung oleh tombol tidak jatuh ke font bawaan.
      fontFamily: inter ? null : 'Roboto',
      fontSize: ukuran,
      height: tinggi / ukuran,
      fontWeight: tebal,
      letterSpacing: jarak,
      color: warna,
    );

    final base = TextTheme(
      displaySmall: gaya(30, 38, tebal: FontWeight.w700, jarak: -0.6),
      headlineMedium: gaya(24, 32, tebal: FontWeight.w700, jarak: -0.4),
      headlineSmall: gaya(20, 26, tebal: FontWeight.w600, jarak: -0.25),
      titleLarge: gaya(18, 24, tebal: FontWeight.w600, jarak: -0.15),
      titleMedium: gaya(16, 22, tebal: FontWeight.w600, jarak: -0.1),
      titleSmall: gaya(14, 20, tebal: FontWeight.w600),
      bodyLarge: gaya(16, 24),
      bodyMedium: gaya(14, 20),
      bodySmall: gaya(12, 16, jarak: 0.1, warna: Warna.teksSekunder),
      labelLarge: gaya(14, 20, tebal: FontWeight.w600, warna: null),
      labelMedium: gaya(
        12,
        16,
        tebal: FontWeight.w500,
        jarak: 0.1,
        warna: null,
      ),
      labelSmall: gaya(11, 14, tebal: FontWeight.w500, jarak: 0.3, warna: null),
    );
    if (!inter) return base;
    return GoogleFonts.interTextTheme(base);
  }
}

/// Angka dengan lebar seragam, untuk hitung mundur dan token agar tidak
/// bergoyang saat digit berubah.
const angkaTabular = [FontFeature.tabularFigures()];
