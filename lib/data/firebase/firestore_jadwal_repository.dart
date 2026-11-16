import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/jadwal.dart';
import '../../models/mata_kuliah.dart';
import '../../models/perubahan_jadwal.dart';
import '../../repositories/jadwal_repository.dart';
import 'tidak_didukung.dart';

class FirestoreJadwalRepository implements JadwalRepository {
  FirestoreJadwalRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _jadwal =>
      _db.collection('jadwal');

  @override
  Stream<List<Jadwal>> semuaJadwal() => _jadwal.snapshots().map(
    (s) =>
        s.docs.map((d) => Jadwal.dariFirestore(d.id, d.data())).toList()
          ..sort((a, b) => a.bandingkan(b)),
  );

  @override
  Stream<List<MataKuliah>> mataKuliah() => _db
      .collection('mata_kuliah')
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => MataKuliah.dariFirestore(d.id, d.data())).toList()
              ..sort((a, b) => a.nama.compareTo(b.nama)),
      );

  @override
  Future<List<Jadwal>> cariBentrok(Jadwal jadwal) async {
    // Rules tidak bisa membandingkan banyak dokumen, jadi bentrok dicek di sini.
    final s = await _jadwal.where('hari', isEqualTo: jadwal.hari).get();
    return s.docs
        .map((d) => Jadwal.dariFirestore(d.id, d.data()))
        .where(jadwal.bentrokDengan)
        .toList();
  }

  @override
  Future<void> simpan(Jadwal jadwal) => jadwal.id.isEmpty
      ? _jadwal.add(jadwal.keFirestore())
      : _jadwal.doc(jadwal.id).set(jadwal.keFirestore());

  @override
  Future<void> hapus(String id) => _jadwal.doc(id).delete();

  @override
  Stream<List<PerubahanJadwal>> perubahanJadwal() => Stream.value(const []);

  @override
  Future<void> simpanMataKuliah(MataKuliah mataKuliah) async => tidakDidukung();

  @override
  Future<void> hapusMataKuliah(String id) async => tidakDidukung();

  @override
  Future<void> simpanPerubahan(PerubahanJadwal perubahan) async =>
      tidakDidukung();

  @override
  Future<void> hapusPerubahan(String id) async => tidakDidukung();
}
