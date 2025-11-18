// lib/models/cuti.dart

class Cuti {
  final int idCuti;
  final String kategori;
  final String tanggalPengajuan;
  final String tanggalMulai;
  final String tanggalAkhir;
  final String statusValidasi;
  final String? keterangan;
  final String? fotoBukti;
  final int sisaKuota;
  final int year; // Menambahkan year
  final int month; // Menambahkan month

  Cuti({
    required this.idCuti,
    required this.kategori,
    required this.tanggalPengajuan,
    required this.tanggalMulai,
    required this.tanggalAkhir,
    required this.statusValidasi,
    this.keterangan,
    this.fotoBukti,
    required this.sisaKuota,
    required this.year, // Pastikan year ada
    required this.month, // Pastikan month ada
  });

  factory Cuti.fromJson(Map<String, dynamic> json) {
    return Cuti(
      idCuti: json['id_cuti'],
      kategori: json['kategori'],
      tanggalPengajuan: json['tanggal_pengajuan'],
      tanggalMulai: json['tanggal_mulai'],
      tanggalAkhir: json['tanggal_akhir'],
      statusValidasi: json['status_validasi'],
      keterangan: json['keterangan'],
      fotoBukti: json['foto_bukti'],
      sisaKuota: json['sisa_kuota'] ?? 0, // Gunakan operator ?? untuk nilai null

      // sisaKuota: json['sisa_kuota'] != null ? json['sisa_kuota'] : 0, // Handle null
      year: json['year'] ?? 2025,  // Default to 2025 if null
      month: json['month'] ?? 5,  // Default to May if null
    );
  }
}
