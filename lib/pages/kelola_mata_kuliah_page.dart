import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/errors.dart';
import '../core/theme.dart';
import '../models/mata_kuliah.dart';
import '../widgets/animasi.dart';
import '../widgets/umum.dart';

void bukaKelolaMataKuliah(BuildContext context) {
  final scope = AppScope.baca(context);
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => scope.bungkus(const KelolaMataKuliahPage()),
    ),
  );
}

/// Admin dan dosen: menambah, mengubah, dan menghapus mata kuliah.
class KelolaMataKuliahPage extends StatefulWidget {
  const KelolaMataKuliahPage({super.key});

  @override
  State<KelolaMataKuliahPage> createState() => _KelolaMataKuliahPageState();
}

class _KelolaMataKuliahPageState extends State<KelolaMataKuliahPage> {
  // Langganan sendiri: AppScope di halaman yang di-push hanya salinan.
  late final Stream<List<MataKuliah>> _mk = AppScope.baca(context).jadwal
      .mataKuliah();

  void _bukaForm(MataKuliah? awal) {
    final scope = AppScope.baca(context);
    bukaLembar<void>(
      context,
      judul: awal == null ? 'Tambah Mata Kuliah' : 'Ubah Mata Kuliah',
      subjudul: 'Dosen pertama dianggap dosen pengampu.',
      isi: (_) => _FormMataKuliah(scope: scope, awal: awal),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Mata Kuliah')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _bukaForm(null),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: StreamBuilder<List<MataKuliah>>(
        stream: _mk,
        builder: (context, snap) {
          final daftar = snap.data;
          final totalSks = (daftar ?? const <MataKuliah>[]).fold<int>(
            0,
            (n, m) => n + m.sks,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              if (daftar == null)
                const KartuKerangka()
              else if (daftar.isEmpty)
                const Kartu(
                  child: KeadaanKosong(
                    ikon: Icons.menu_book_outlined,
                    judul: 'Belum ada mata kuliah',
                    pesan: 'Tekan Tambah untuk membuat mata kuliah pertama.',
                  ),
                )
              else ...[
                Wrap(
                  spacing: 8,
                  children: [
                    ChipStatus(
                      '${daftar.length} mata kuliah',
                      jenis: JenisStatus.info,
                    ),
                    ChipStatus('$totalSks SKS', jenis: JenisStatus.netral),
                  ],
                ),
                const SizedBox(height: 16),
                for (final (i, m) in daftar.indexed) ...[
                  Muncul(
                    urutan: i,
                    child: Kartu(
                      onTap: () => _bukaForm(m),
                      child: Row(
                        children: [
                          const IkonKotak(Icons.menu_book_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.nama, style: t.titleSmall),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    if (m.kode.isNotEmpty) m.kode,
                                    '${m.sks} SKS',
                                    if (m.dosenPengampu != null)
                                      m.dosenPengampu!,
                                  ].join(' • '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: Warna.teksSekunder,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _FormMataKuliah extends StatefulWidget {
  const _FormMataKuliah({required this.scope, this.awal});

  final AppScope scope;
  final MataKuliah? awal;

  @override
  State<_FormMataKuliah> createState() => _FormMataKuliahState();
}

class _FormMataKuliahState extends State<_FormMataKuliah> {
  final _kunci = GlobalKey<FormState>();
  late final _nama = TextEditingController(text: widget.awal?.nama ?? '');
  late final _kode = TextEditingController(text: widget.awal?.kode ?? '');
  late final _sks = TextEditingController(
    text: widget.awal == null ? '3' : '${widget.awal!.sks}',
  );
  late final _dosen = TextEditingController(
    text: (widget.awal?.dosen ?? const []).join('\n'),
  );
  bool _memproses = false;
  String? _galat;

  @override
  void dispose() {
    for (final c in [_nama, _kode, _sks, _dosen]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _jalankan(Future<void> Function() aksi, String pesan) async {
    setState(() {
      _memproses = true;
      _galat = null;
    });
    try {
      await aksi();
      if (mounted) {
        Navigator.pop(context);
        tampilkanPesan(context, pesan);
      }
    } on ClassMateException catch (e) {
      if (mounted) setState(() => _galat = e.pesan);
    } catch (e) {
      if (mounted) setState(() => _galat = '$e');
    } finally {
      if (mounted) setState(() => _memproses = false);
    }
  }

  Future<void> _simpan() async {
    if (!_kunci.currentState!.validate()) return;
    final mk = MataKuliah(
      id: widget.awal?.id ?? '',
      nama: _nama.text.trim(),
      kelasId: widget.awal?.kelasId,
      kode: _kode.text.trim(),
      sks: int.parse(_sks.text.trim()),
      dosen: _dosen.text
          .split('\n')
          .map((d) => d.trim())
          .where((d) => d.isNotEmpty)
          .toList(),
    );
    await _jalankan(
      () => widget.scope.jadwal.simpanMataKuliah(mk),
      'Mata kuliah ${mk.nama} disimpan.',
    );
  }

  Future<void> _hapus() async {
    final awal = widget.awal!;
    final ya = await konfirmasi(
      context,
      ikon: Icons.delete_outline,
      judul: 'Hapus ${awal.nama}?',
      pesan:
          'Semua jadwal, sesi absensi, kehadiran, tugas, dan pengumpulan '
          'mata kuliah ini ikut terhapus. Tindakan ini tidak bisa dibatalkan.',
      tombolYa: 'Hapus Mata Kuliah',
      bahaya: true,
    );
    if (!ya || !mounted) return;
    await _jalankan(
      () => widget.scope.jadwal.hapusMataKuliah(awal.id),
      '${awal.nama} dihapus.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _kunci,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nama,
            enabled: !_memproses,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nama mata kuliah'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _kode,
                  enabled: !_memproses,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Kode'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _sks,
                  enabled: !_memproses,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'SKS'),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    return n == null || n < 0 || n > 24 ? '0–24' : null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _dosen,
            enabled: !_memproses,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Dosen (satu nama per baris)',
              alignLabelWithHint: true,
            ),
          ),
          if (_galat != null) ...[
            const SizedBox(height: 16),
            KotakInfo(
              jenis: JenisStatus.bahaya,
              ikon: Icons.error_outline,
              teks: _galat!,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _memproses ? null : _simpan,
            child: Text(_memproses ? 'Menyimpan…' : 'Simpan Mata Kuliah'),
          ),
          if (widget.awal != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _memproses ? null : _hapus,
              style: TextButton.styleFrom(foregroundColor: Warna.bahaya),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Hapus Mata Kuliah'),
            ),
          ],
        ],
      ),
    );
  }
}
