import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/errors.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/pengumuman.dart';
import '../repositories/pengumuman_repository.dart';
import '../widgets/animasi.dart';
import '../widgets/umum.dart';

/// Membuka halaman Pengumuman di atas tab yang sedang aktif.
Future<void> bukaPengumuman(BuildContext context) {
  final scope = AppScope.baca(context);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => scope.bungkus(const PengumumanPage()),
    ),
  );
}

class PengumumanPage extends StatefulWidget {
  const PengumumanPage({super.key});

  @override
  State<PengumumanPage> createState() => _PengumumanPageState();
}

class _PengumumanPageState extends State<PengumumanPage> {
  late Future<List<Pengumuman>> _daftar;

  PengumumanRepository get _repo => AppScope.baca(context).pengumuman;

  @override
  void initState() {
    super.initState();
    _daftar = _repo.daftar();
  }

  Future<void> _segarkan() async {
    final baru = _repo.daftar();
    setState(() => _daftar = baru);
    try {
      await baru;
    } catch (_) {
      // Galat ditampilkan oleh FutureBuilder.
    }
  }

  Future<void> _form([Pengumuman? awal]) async {
    final repo = _repo;
    final hasil = await bukaLembar<String>(
      context,
      judul: awal == null ? 'Buat Pengumuman' : 'Ubah Pengumuman',
      subjudul: 'Pengumuman tampil di beranda semua anggota kelas.',
      isi: (_) => _FormPengumuman(repo: repo, awal: awal),
    );
    if (!mounted || hasil == null) return;
    tampilkanPesan(
      context,
      hasil == 'hapus' ? 'Pengumuman dihapus.' : 'Pengumuman tersimpan.',
    );
    _segarkan();
  }

  @override
  Widget build(BuildContext context) {
    final pengelola = AppScope.of(context).pengguna.isAdmin;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pengumuman')),
      floatingActionButton: pengelola
          ? FloatingActionButton.extended(
              onPressed: () => _form(),
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Buat Pengumuman'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _segarkan,
        child: FutureBuilder<List<Pengumuman>>(
          future: _daftar,
          builder: (context, snap) {
            if (snap.hasError) {
              final e = snap.error;
              return ListView(
                children: [
                  KeadaanKosong(
                    ikon: Icons.cloud_off_outlined,
                    judul: 'Pengumuman belum bisa dimuat',
                    pesan: e is ClassMateException ? e.pesan : '$e',
                    aksi: OutlinedButton.icon(
                      onPressed: _segarkan,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba lagi'),
                    ),
                  ),
                ],
              );
            }
            final daftar = snap.data;
            if (daftar == null) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: const [KartuKerangka()],
              );
            }
            if (daftar.isEmpty) {
              return ListView(
                children: [
                  KeadaanKosong(
                    ikon: Icons.campaign_outlined,
                    judul: 'Belum ada pengumuman',
                    pesan: pengelola
                        ? 'Bagikan info kuis, perubahan kelas, atau tagihan '
                              'iuran ke semua anggota.'
                        : 'Pengumuman dari ketua kelas dan dosen akan muncul '
                              'di sini.',
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: daftar.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final p = daftar[i];
                return Muncul(
                  key: ValueKey(p.id),
                  urutan: i,
                  child: Kartu(
                    strip: p.penting ? Warna.bahaya : null,
                    onTap: pengelola ? () => _form(p) : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IkonKotak(
                              Icons.campaign_outlined,
                              jenis: p.penting
                                  ? JenisStatus.bahaya
                                  : JenisStatus.info,
                              ukuran: 36,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                [
                                  if (p.namaPembuat != null) p.namaPembuat!,
                                  formatRelatif(p.dibuatPada),
                                ].join(' • '),
                                style: t.bodySmall,
                              ),
                            ),
                            if (p.penting)
                              const ChipStatus(
                                'Penting',
                                jenis: JenisStatus.bahaya,
                              )
                            else if (p.baru())
                              const ChipStatus('Baru', jenis: JenisStatus.info),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(p.judul, style: t.titleMedium),
                        if (p.isi.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(p.isi, style: t.bodyMedium),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _FormPengumuman extends StatefulWidget {
  const _FormPengumuman({required this.repo, this.awal});

  final PengumumanRepository repo;
  final Pengumuman? awal;

  @override
  State<_FormPengumuman> createState() => _FormPengumumanState();
}

class _FormPengumumanState extends State<_FormPengumuman> {
  late final _judul = TextEditingController(text: widget.awal?.judul ?? '');
  late final _isi = TextEditingController(text: widget.awal?.isi ?? '');
  late bool _penting = widget.awal?.penting ?? false;
  bool _memproses = false;

  @override
  void dispose() {
    _judul.dispose();
    _isi.dispose();
    super.dispose();
  }

  Future<void> _jalankan(Future<void> Function() aksi, String hasil) async {
    setState(() => _memproses = true);
    try {
      await aksi();
      if (mounted) Navigator.pop(context, hasil);
    } on ClassMateException catch (e) {
      if (mounted) {
        setState(() => _memproses = false);
        tampilkanPesan(context, e.pesan, gagal: true);
      }
    }
  }

  Future<void> _hapus() async {
    final ya = await konfirmasi(
      context,
      ikon: Icons.delete_outline,
      judul: 'Hapus pengumuman ini?',
      pesan: 'Pengumuman hilang dari beranda semua anggota.',
      tombolYa: 'Hapus',
      bahaya: true,
    );
    if (!ya || !mounted) return;
    await _jalankan(() => widget.repo.hapus(widget.awal!.id), 'hapus');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _judul,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Judul'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _isi,
          minLines: 3,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Isi pengumuman',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _penting,
          onChanged: (v) => setState(() => _penting = v),
          title: const Text('Tandai penting'),
          subtitle: const Text('Ditonjolkan di bagian atas beranda.'),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _memproses || _judul.text.trim().isEmpty
              ? null
              : () => _jalankan(
                  () => widget.repo.simpan(
                    (widget.awal ?? const Pengumuman(judul: '')).salin(
                      judul: _judul.text,
                      isi: _isi.text,
                      penting: _penting,
                    ),
                  ),
                  'simpan',
                ),
          icon: const Icon(Icons.send_outlined),
          label: Text(
            _memproses
                ? 'Menyimpan…'
                : widget.awal == null
                ? 'Umumkan'
                : 'Simpan Perubahan',
          ),
        ),
        if (widget.awal != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Warna.bahaya),
            onPressed: _memproses ? null : _hapus,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Hapus Pengumuman'),
          ),
        ],
      ],
    );
  }
}
