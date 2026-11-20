import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors.dart';
import '../../models/kehadiran.dart';
import '../../models/pengguna.dart';
import '../../models/sesi_absensi.dart';
import '../../models/rekap_kehadiran.dart';
import '../../repositories/absensi_repository.dart';
import 'tidak_didukung.dart';

class FirestoreAbsensiRepository implements AbsensiRepository {
  FirestoreAbsensiRepository(this._db, this._pengguna);

  final FirebaseFirestore _db;
  final Pengguna _pengguna;

  CollectionReference<Map<String, dynamic>> get _sesi =>
      _db.collection('sesi_absensi');

  @override
  Stream<List<SesiAbsensi>> sesiAktif() => _sesi
      .where('status', isEqualTo: 'buka')
      .snapshots()
      .map(
        (s) =>
            s.docs
                .map((d) => SesiAbsensi.dariFirestore(d.id, d.data()))
                .toList()
              ..sort((a, b) => a.berakhir.compareTo(b.berakhir)),
      );

  @override
  Stream<Set<String>> sesiYangSudahDihadiri() => _db
      .collection('kehadiran')
      .where('uid', isEqualTo: _pengguna.uid)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()['sesi_id'] as String).toSet());

  @override
  Future<void> hadir(String sesiId, String token) async {
    final ref = _db
        .collection('kehadiran')
        .doc(Kehadiran.idDokumen(sesiId, _pengguna.uid));
    try {
      final ada = await ref.get(const GetOptions(source: Source.server));
      if (ada.exists) {
        throw const ClassMateException('Kamu sudah absen di sesi ini.');
      }
      // Token, waktu server, dan keanggotaan diperiksa oleh Security Rules.
      await ref
          .set({
            'sesi_id': sesiId,
            'uid': _pengguna.uid,
            'email': _pengguna.email,
            'token': token.trim().toUpperCase(),
            'waktu_absen': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const ClassMateException(
        'Koneksi lambat. Periksa internet lalu coba lagi.',
      );
    } on FirebaseException catch (e) {
      throw switch (e.code) {
        'permission-denied' => const ClassMateException(
          'Token salah atau sesi sudah berakhir.',
        ),
        'unavailable' => const ClassMateException(
          'Tidak ada koneksi internet. Coba lagi.',
        ),
        _ => ClassMateException('Gagal absen: ${e.message ?? e.code}'),
      };
    }
  }

  @override
  Future<String> buatSesi({
    required String mataKuliahId,
    required DateTime mulai,
    required DateTime berakhir,
  }) async {
    final token = AbsensiRepository.buatToken();
    final ref = _sesi.doc();
    final batch = _db.batch()
      ..set(
        ref,
        SesiAbsensi(
          id: ref.id,
          mataKuliahId: mataKuliahId,
          mulai: mulai,
          berakhir: berakhir,
          status: 'buka',
        ).keFirestore(),
      )
      ..set(ref.collection('rahasia').doc('token'), {'nilai': token});
    await batch.commit();
    return token;
  }

  @override
  Future<String> tokenSesi(String sesiId) async {
    final doc = await _sesi
        .doc(sesiId)
        .collection('rahasia')
        .doc('token')
        .get();
    return (doc.data()?['nilai'] as String?) ?? '-';
  }

  @override
  Future<void> tutupSesi(String sesiId) =>
      _sesi.doc(sesiId).update({'status': 'tutup'});

  @override
  Stream<List<Kehadiran>> rekapSesi(String sesiId) => _db
      .collection('kehadiran')
      .where('sesi_id', isEqualTo: sesiId)
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => Kehadiran.dariFirestore(d.data())).toList()
              ..sort((a, b) => a.waktuAbsen.compareTo(b.waktuAbsen)),
      );

  @override
  Future<RekapKehadiran> rekapKehadiranSaya() async => tidakDidukung();
}
