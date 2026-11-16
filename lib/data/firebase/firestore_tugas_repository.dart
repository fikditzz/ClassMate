import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors.dart';
import '../../models/pengguna.dart';
import '../../models/pengumpulan.dart';
import '../../models/tugas.dart';
import '../../repositories/penyimpanan_berkas.dart';
import '../../repositories/tugas_repository.dart';
import 'tidak_didukung.dart';

class FirestoreTugasRepository implements TugasRepository {
  FirestoreTugasRepository(this._db, this._pengguna);

  final FirebaseFirestore _db;
  final Pengguna _pengguna;

  @override
  Stream<List<Tugas>> daftarTugas() => _db
      .collection('tugas')
      .orderBy('tenggat')
      .snapshots()
      .map(
        (s) => s.docs.map((d) => Tugas.dariFirestore(d.id, d.data())).toList(),
      );

  @override
  Stream<Map<String, Pengumpulan>> pengumpulanSaya() => _db
      .collection('pengumpulan')
      .where('uid', isEqualTo: _pengguna.uid)
      .snapshots()
      .map(
        (s) => {
          for (final d in s.docs)
            (d.data()['tugas_id'] as String): Pengumpulan.dariFirestore(
              d.data(),
            ),
        },
      );

  @override
  Future<void> catatPengumpulan(Tugas tugas, BerkasTerunggah berkas) async {
    if (tugas.sudahLewatTenggat()) {
      throw const ClassMateException('Tenggat tugas ini sudah lewat.');
    }
    try {
      await _db
          .collection('pengumpulan')
          .doc(Pengumpulan.idDokumen(tugas.id, _pengguna.uid))
          .set({
            'tugas_id': tugas.id,
            'uid': _pengguna.uid,
            'email': _pengguna.email,
            'drive_file_id': berkas.fileId,
            'drive_url': berkas.url,
            'nama_file': berkas.nama,
            'ukuran': berkas.ukuran,
            'waktu_upload': FieldValue.serverTimestamp(),
          });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const ClassMateException(
          'Pengumpulan ditolak: tenggat sudah lewat.',
        );
      }
      throw ClassMateException(
        'Gagal menyimpan pengumpulan: ${e.message ?? e.code}',
      );
    }
  }

  @override
  Future<void> buatTugas(Tugas tugas) => _db.collection('tugas').add({
    ...tugas.keFirestore(),
    'dibuat_oleh': _pengguna.email,
  });

  @override
  Future<void> ubahTugas(Tugas tugas) async => tidakDidukung();

  @override
  Future<void> hapusTugas(String id) async => tidakDidukung();

  @override
  Stream<List<Pengumpulan>> pengumpulanTugas(String tugasId) => _db
      .collection('pengumpulan')
      .where('tugas_id', isEqualTo: tugasId)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => Pengumpulan.dariFirestore(d.data())).toList(),
      );
}
