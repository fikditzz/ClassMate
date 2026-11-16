import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_scope.dart';
import '../core/format.dart';
import '../core/theme.dart';
import 'animasi.dart';
import 'animasi_lanjut.dart';
import 'logo.dart';

enum JenisStatus { sukses, bahaya, peringatan, info, netral }

extension WarnaStatus on JenisStatus {
  Color get latar => switch (this) {
    JenisStatus.sukses => Warna.suksesMuda,
    JenisStatus.bahaya => Warna.bahayaMuda,
    JenisStatus.peringatan => Warna.peringatanMuda,
    JenisStatus.info => Warna.primerMuda,
    JenisStatus.netral => Warna.netralMuda,
  };

  Color get depan => switch (this) {
    JenisStatus.sukses => Warna.sukses,
    JenisStatus.bahaya => Warna.bahaya,
    JenisStatus.peringatan => Warna.peringatanTeks,
    JenisStatus.info => Warna.primer,
    JenisStatus.netral => Warna.netral,
  };

  /// Warna strip kiri kartu.
  Color get strip => switch (this) {
    JenisStatus.peringatan => Warna.peringatan,
    _ => depan,
  };
}

/// Chip status berbentuk pil (tinggi 28, padding 10).
class ChipStatus extends StatelessWidget {
  const ChipStatus(
    this.teks, {
    super.key,
    required this.jenis,
    this.ikon,
    this.titik = false,
  });

  final String teks;
  final JenisStatus jenis;
  final IconData? ikon;
  final bool titik;

  @override
  Widget build(BuildContext context) {
    final warna = jenis.depan;
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: jenis.latar,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (titik) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          if (ikon != null) ...[
            Icon(ikon, size: 14, color: warna),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              teks,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: warna, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu putih sudut 16 dengan bayangan Elev-1 dan strip status opsional
/// selebar 4px di sisi kiri.
class Kartu extends StatelessWidget {
  const Kartu({
    super.key,
    required this.child,
    this.strip,
    this.warna = Warna.permukaan,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.bayangan = true,
  });

  final Widget child;
  final Color? strip;
  final Color warna;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool bayangan;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    Widget isi = Padding(
      // Strip ditumpuk di atas padding (tidak menggeser isi), jadi teks
      // kartu ber-strip dan tanpa strip tetap sejajar.
      padding: padding,
      child: child,
    );
    if (strip != null) {
      isi = Stack(
        children: [
          isi,
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: ColoredBox(color: strip!),
          ),
        ],
      );
    }
    return TekanSkala(
      aktif: onTap != null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: bayangan ? Bayangan.elev1 : null,
        ),
        child: Material(
          color: warna,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: onTap == null ? isi : InkWell(onTap: onTap, child: isi),
        ),
      ),
    );
  }
}

/// Kotak berwarna lembut dengan ikon, untuk info tenggat, peringatan, dll.
class KotakInfo extends StatelessWidget {
  const KotakInfo({
    super.key,
    required this.teks,
    this.judul,
    this.ikon = Icons.info_outline,
    this.jenis = JenisStatus.info,
    this.trailing,
  });

  final String teks;
  final String? judul;
  final IconData ikon;
  final JenisStatus jenis;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: jenis.latar,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 20, color: jenis.depan),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (judul != null)
                  Text(
                    judul!,
                    style: t.labelLarge?.copyWith(color: jenis.depan),
                  ),
                Text(
                  teks,
                  style: t.bodyMedium?.copyWith(
                    color: judul == null ? jenis.depan : Warna.teks,
                    fontWeight: judul == null ? FontWeight.w500 : null,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// Judul bagian dengan aksi "Lihat Semua" dan lencana jumlah opsional.
class JudulBagian extends StatelessWidget {
  const JudulBagian(
    this.teks, {
    super.key,
    this.aksi,
    this.onAksi,
    this.jumlah,
    this.atas = 24,
  });

  final String teks;
  final String? aksi;
  final VoidCallback? onAksi;
  final int? jumlah;
  final double atas;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(top: atas, bottom: 12),
      child: Row(
        children: [
          // Judul mengambil semua sisa ruang; tombol aksi memakai lebar alaminya.
          Expanded(
            child: Row(
              children: [
                Flexible(child: Text(teks, style: t.titleMedium)),
                if (jumlah != null && jumlah! > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Warna.bahayaMuda,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: AngkaBerganti(
                      jumlah!,
                      style: t.labelMedium?.copyWith(color: Warna.bahaya),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (aksi != null)
            TextButton(
              onPressed: onAksi,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(aksi!),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Label huruf kapital kecil, misalnya "JADWAL KULIAH".
class LabelAtas extends StatelessWidget {
  const LabelAtas(this.teks, {super.key, this.warna = Warna.primer});

  final String teks;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Text(
      teks.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: warna,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }
}

class AvatarInisial extends StatelessWidget {
  const AvatarInisial(this.nama, {super.key, this.ukuran = 40});

  final String nama;
  final double ukuran;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ukuran,
      height: ukuran,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Warna.primerMuda,
        shape: BoxShape.circle,
      ),
      child: Text(
        inisial(nama),
        style: TextStyle(
          color: Warna.primer,
          fontWeight: FontWeight.w700,
          fontSize: ukuran * 0.36,
        ),
      ),
    );
  }
}

/// Ikon dalam kotak sudut 12 berwarna lembut.
class IkonKotak extends StatelessWidget {
  const IkonKotak(
    this.ikon, {
    super.key,
    this.jenis = JenisStatus.info,
    this.ukuran = 40,
  });

  final IconData ikon;
  final JenisStatus jenis;
  final double ukuran;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ukuran,
      height: ukuran,
      decoration: BoxDecoration(
        color: jenis.latar,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(ikon, color: jenis.depan, size: ukuran * 0.55),
    );
  }
}

/// AppBar standar: label kecil di atas judul, dan avatar yang membuka Profil.
PreferredSizeWidget appBarClassMate(
  BuildContext context, {
  required String judul,
  String? labelAtas = 'ClassMate',
  bool logo = false,
  bool avatar = true,
  String? subjudul,
  PreferredSizeWidget? bawah,
}) {
  final scope = AppScope.of(context);
  final t = Theme.of(context).textTheme;
  return AppBar(
    toolbarHeight: 64,
    bottom: bawah,
    title: Row(
      children: [
        if (logo) ...[
          const LogoClassMate(ukuran: 44),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (labelAtas != null) LabelAtas(labelAtas),
              Text(
                judul,
                style: t.headlineSmall,
                overflow: TextOverflow.ellipsis,
              ),
              if (subjudul != null)
                Text(
                  subjudul,
                  style: t.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    ),
    actions: [
      if (avatar)
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => scope.bukaTab(4),
            child: AvatarInisial(scope.pengguna.nama, ukuran: 40),
          ),
        ),
    ],
  );
}

/// Keterangan untuk halaman atau bagian yang belum berisi data.
class KeadaanKosong extends StatelessWidget {
  const KeadaanKosong({
    super.key,
    required this.ikon,
    required this.judul,
    this.pesan,
    this.ringkas = false,
    this.aksi,
  });

  final IconData ikon;
  final String judul;
  final String? pesan;
  final bool ringkas;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: ringkas ? 20 : 48,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ringkas ? 56 : 88,
            height: ringkas ? 56 : 88,
            decoration: const BoxDecoration(
              color: Warna.primerMuda,
              shape: BoxShape.circle,
            ),
            child: Icon(ikon, size: ringkas ? 28 : 40, color: Warna.primer),
          ),
          const SizedBox(height: 16),
          Text(
            judul,
            textAlign: TextAlign.center,
            style: ringkas ? t.titleSmall : t.titleMedium,
          ),
          if (pesan != null) ...[
            const SizedBox(height: 4),
            Text(pesan!, textAlign: TextAlign.center, style: t.bodySmall),
          ],
          if (aksi != null) ...[const SizedBox(height: 16), aksi!],
        ],
      ),
    );
  }
}

/// Kotak abu-abu pengganti konten selama data dimuat.
class Kerangka extends StatelessWidget {
  const Kerangka({super.key, this.tinggi = 16, this.lebar, this.sudut = 8});

  final double tinggi;
  final double? lebar;
  final double sudut;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: tinggi,
      width: lebar,
      decoration: BoxDecoration(
        color: Warna.netralMuda,
        borderRadius: BorderRadius.circular(sudut),
      ),
    );
  }
}

class KartuKerangka extends StatelessWidget {
  const KartuKerangka({super.key});

  @override
  Widget build(BuildContext context) {
    return const Kartu(
      child: Kilau(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Kerangka(lebar: 120),
            SizedBox(height: 12),
            Kerangka(tinggi: 20),
            SizedBox(height: 8),
            Kerangka(lebar: 180),
          ],
        ),
      ),
    );
  }
}

/// Membangun ulang [builder] setiap detik dengan sisa waktu menuju [batas].
class HitungMundur extends StatefulWidget {
  const HitungMundur({super.key, required this.batas, required this.builder});

  final DateTime batas;
  final Widget Function(BuildContext context, Duration sisa) builder;

  @override
  State<HitungMundur> createState() => _HitungMundurState();
}

class _HitungMundurState extends State<HitungMundur> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (DateTime.now().isAfter(widget.batas)) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, widget.batas.difference(DateTime.now()));
}

/// Input token 6 karakter berbentuk kotak-kotak.
class InputToken extends StatefulWidget {
  const InputToken({
    super.key,
    required this.controller,
    this.onSelesai,
    this.aktif = true,
    this.galat = false,
  });

  static const panjang = 6;

  final TextEditingController controller;
  final VoidCallback? onSelesai;
  final bool aktif;
  final bool galat;

  @override
  State<InputToken> createState() => _InputTokenState();
}

class _InputTokenState extends State<InputToken> {
  final _fokus = FocusNode();

  /// Bertambah setiap kali input berubah menjadi salah, memicu goyangan.
  int _goyangKe = 0;

  @override
  void didUpdateWidget(InputToken lama) {
    super.didUpdateWidget(lama);
    if (widget.galat && !lama.galat) _goyangKe++;
  }

  @override
  void dispose() {
    _fokus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: widget.aktif ? _fokus.requestFocus : null,
      child: Stack(
        children: [
          // Field asli tidak terlihat; kotak-kotak di atasnya hanya tampilan.
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 56,
              child: TextField(
                controller: widget.controller,
                focusNode: _fokus,
                enabled: widget.aktif,
                maxLength: InputToken.panjang,
                autocorrect: false,
                enableSuggestions: false,
                showCursor: false,
                textCapitalization: TextCapitalization.characters,
                keyboardType: TextInputType.visiblePassword,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                  TextInputFormatter.withFunction(
                    (_, baru) => baru.copyWith(text: baru.text.toUpperCase()),
                  ),
                ],
                onChanged: (v) {
                  if (v.length == InputToken.panjang) widget.onSelesai?.call();
                },
                onSubmitted: (_) => widget.onSelesai?.call(),
                decoration: const InputDecoration(counterText: ''),
              ),
            ),
          ),
          Goyang(
            pemicu: _goyangKe == 0 ? null : _goyangKe,
            child: ListenableBuilder(
              listenable: Listenable.merge([widget.controller, _fokus]),
              builder: (context, _) {
                final teks = widget.controller.text;
                return Row(
                  children: [
                    for (var i = 0; i < InputToken.panjang; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: _kotak(t, teks, i)),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _kotak(TextTheme t, String teks, int i) {
    final terisi = i < teks.length;
    final sekarang = _fokus.hasFocus && i == teks.length;
    final warnaGaris = widget.galat
        ? Warna.bahaya
        : (terisi || sekarang)
        ? Warna.primer
        : Warna.garis;
    final Widget isi;
    if (terisi) {
      isi = Text(
        teks[i],
        key: ValueKey('h$i${teks[i]}'),
        style: t.headlineSmall?.copyWith(
          color: widget.galat ? Warna.bahaya : Warna.primer,
          fontWeight: FontWeight.w700,
          fontFeatures: angkaTabular,
        ),
      );
    } else if (sekarang) {
      isi = Denyut(
        key: const ValueKey('kursor'),
        child: Container(width: 2, height: 24, color: Warna.primer),
      );
    } else {
      isi = Container(
        key: const ValueKey('titik'),
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: Warna.garis,
          shape: BoxShape.circle,
        ),
      );
    }
    return AnimatedContainer(
      duration: Gerak.cepat,
      curve: Curves.easeOut,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.galat && terisi
            ? Warna.bahayaMuda
            : terisi
            ? Warna.primerMuda
            : Warna.permukaan,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warnaGaris, width: sekarang ? 2 : 1.5),
      ),
      // Huruf baru muncul dengan membesar singkat.
      child: AnimatedSwitcher(
        duration: Gerak.cepat,
        transitionBuilder: (anak, a) => ScaleTransition(
          scale: Tween(begin: 0.6, end: 1.0).animate(a),
          child: FadeTransition(opacity: a, child: anak),
        ),
        child: isi,
      ),
    );
  }
}

/// Kotak dengan garis putus-putus, untuk area unggah berkas.
class KotakPutusPutus extends StatelessWidget {
  const KotakPutusPutus({
    super.key,
    required this.child,
    this.warna = Warna.primer,
  });

  final Widget child;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GarisPutus(warna),
      child: Padding(padding: const EdgeInsets.all(24), child: child),
    );
  }
}

class _GarisPutus extends CustomPainter {
  _GarisPutus(this.warna);

  final Color warna;

  @override
  void paint(Canvas canvas, Size size) {
    final cat = Paint()
      ..color = warna
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final jalur = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      );
    for (final m in jalur.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 10) {
        canvas.drawPath(m.extractPath(d, d + 6), cat);
      }
    }
  }

  @override
  bool shouldRepaint(_GarisPutus old) => old.warna != warna;
}

/// Menampilkan pesan hasil aksi di bagian bawah layar.
void tampilkanPesan(BuildContext context, String pesan, {bool gagal = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(pesan),
        backgroundColor: gagal ? Warna.bahaya : Warna.teks,
      ),
    );
}

/// Lembar bawah dengan judul dan padding yang konsisten.
Future<T?> bukaLembar<T>(
  BuildContext context, {
  required String judul,
  String? subjudul,
  required WidgetBuilder isi,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) {
      final t = Theme.of(context).textTheme;
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(judul, style: t.headlineSmall),
              if (subjudul != null) ...[
                const SizedBox(height: 4),
                Text(
                  subjudul,
                  style: t.bodyMedium?.copyWith(color: Warna.teksSekunder),
                ),
              ],
              const SizedBox(height: 20),
              isi(context),
            ],
          ),
        ),
      );
    },
  );
}

/// Dialog konfirmasi dengan tombol utama di bawah (gaya desain 8d).
Future<bool> konfirmasi(
  BuildContext context, {
  required IconData ikon,
  required String judul,
  required String pesan,
  required String tombolYa,
  bool bahaya = false,
}) async {
  final hasil = await showDialog<bool>(
    context: context,
    builder: (context) {
      final t = Theme.of(context).textTheme;
      final jenis = bahaya ? JenisStatus.bahaya : JenisStatus.info;
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: IkonKotak(ikon, jenis: jenis, ukuran: 56)),
              const SizedBox(height: 16),
              Text(judul, textAlign: TextAlign.center, style: t.headlineSmall),
              const SizedBox(height: 8),
              Text(
                pesan,
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(color: Warna.teksSekunder),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: bahaya
                    ? FilledButton.styleFrom(backgroundColor: Warna.bahaya)
                    : null,
                onPressed: () => Navigator.pop(context, true),
                child: Text(tombolYa),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
            ],
          ),
        ),
      );
    },
  );
  return hasil ?? false;
}
