import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/pengguna.dart';
import '../backend.dart';
import 'firebase_auth_repository.dart';
import 'firestore_absensi_repository.dart';
import 'firestore_jadwal_repository.dart';
import 'firestore_tugas_repository.dart';
import 'tidak_didukung.dart';

class FirebaseBackend implements BackendClassMate {
  FirebaseBackend({FirebaseFirestore? db, FirebaseAuth? firebaseAuth})
    : _db = db ?? FirebaseFirestore.instance,
      auth = FirebaseAuthRepository(
        firebaseAuth ?? FirebaseAuth.instance,
        db ?? FirebaseFirestore.instance,
      );

  final FirebaseFirestore _db;

  @override
  final FirebaseAuthRepository auth;

  @override
  bool get modeDemo => false;

  @override
  RepositoriPengguna buatRepositori(Pengguna pengguna) => RepositoriPengguna(
    absensi: FirestoreAbsensiRepository(_db, pengguna),
    tugas: FirestoreTugasRepository(_db, pengguna),
    jadwal: FirestoreJadwalRepository(_db),
    akun: const AkunTidakDidukung(),
    kas: const KasTidakDidukung(),
    pengumuman: const PengumumanTidakDidukung(),
  );
}
