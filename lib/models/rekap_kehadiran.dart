/// Kehadiran pengguna di satu mata kuliah.
class RekapKehadiranMk {
  const RekapKehadiranMk({
    required this.mataKuliahId,
    required this.totalSesi,
    required this.hadir,
  });

  final String mataKuliahId;

  /// Sesi yang sudah dimulai dan tidak dibatalkan.
  final int totalSesi;
  final int hadir;

  int get absen => totalSesi - hadir;

  /// 0..1; 1 bila belum ada sesi.
  double get persen => totalSesi == 0 ? 1 : hadir / totalSesi;
}

/// Ringkasan kehadiran seluruh mata kuliah.
class RekapKehadiran {
  const RekapKehadiran(this.perMataKuliah);

  final List<RekapKehadiranMk> perMataKuliah;

  int get totalSesi => perMataKuliah.fold(0, (a, r) => a + r.totalSesi);
  int get hadir => perMataKuliah.fold(0, (a, r) => a + r.hadir);

  /// 0..1, atau null bila belum ada sesi sama sekali.
  double? get persen => totalSesi == 0 ? null : hadir / totalSesi;

  /// Hitung dari daftar sesi (mata kuliah per sesi) dan sesi yang dihadiri.
  static RekapKehadiran hitung({
    required Map<String, String> mataKuliahPerSesi,
    required Set<String> sesiDihadiri,
  }) {
    final total = <String, int>{};
    final hadir = <String, int>{};
    mataKuliahPerSesi.forEach((sesi, mk) {
      total[mk] = (total[mk] ?? 0) + 1;
      if (sesiDihadiri.contains(sesi)) hadir[mk] = (hadir[mk] ?? 0) + 1;
    });
    final daftar = [
      for (final mk in total.keys)
        RekapKehadiranMk(
          mataKuliahId: mk,
          totalSesi: total[mk]!,
          hadir: hadir[mk] ?? 0,
        ),
    ]..sort((a, b) => a.persen.compareTo(b.persen));
    return RekapKehadiran(daftar);
  }
}
