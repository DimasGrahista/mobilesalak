// lib/models/cuti.dart

class Cuti {
  final int idCuti;
  final int idKaryawan; // ← Ditambahkan untuk relasi ke karyawan
  final String kategori;
  final String tanggalPengajuan;
  final String tanggalMulai;
  final String tanggalAkhir;
  final String statusValidasi;
  final String? keterangan;
  final String? fotoBukti;
  final int sisaKuota;
  final int year;
  final int month;
  final String? alasanPenolakan;

  Cuti({
    required this.idCuti,
    required this.idKaryawan, // ← Ditambahkan
    required this.kategori,
    required this.tanggalPengajuan,
    required this.tanggalMulai,
    required this.tanggalAkhir,
    required this.statusValidasi,
    this.keterangan,
    this.fotoBukti,
    required this.sisaKuota,
    required this.year,
    required this.month,
    this.alasanPenolakan,
  });

  // Factory constructor untuk parsing dari JSON
  factory Cuti.fromJson(Map<String, dynamic> json) {
    // Parse tanggal pengajuan untuk mendapatkan year dan month jika tidak ada di JSON
    DateTime? tanggalParsed;
    try {
      tanggalParsed = DateTime.parse(json['tanggal_pengajuan'] ?? '');
    } catch (e) {
      tanggalParsed = DateTime.now();
    }

    return Cuti(
      idCuti: json['id_cuti'] ?? 0,
      idKaryawan: json['id_karyawan'] ?? 0, // ← Handle null
      kategori: json['kategori'] ?? 'Cuti',
      tanggalPengajuan: json['tanggal_pengajuan'] ?? '',
      tanggalMulai: json['tanggal_mulai'] ?? '',
      tanggalAkhir: json['tanggal_akhir'] ?? '',
      statusValidasi: json['status_validasi'] ?? 'Pending',
      keterangan: json['keterangan'],
      fotoBukti: json['foto_bukti'],
      sisaKuota: json['sisa_kuota'] ?? 0,
      // Gunakan year/month dari JSON atau parse dari tanggal_pengajuan
      year: json['year'] ?? tanggalParsed.year,
      month: json['month'] ?? tanggalParsed.month,
      alasanPenolakan: json['alasan_penolakan'],
    );
  }

  // Method untuk convert object ke JSON
  Map<String, dynamic> toJson() {
    return {
      'id_cuti': idCuti,
      'id_karyawan': idKaryawan,
      'kategori': kategori,
      'tanggal_pengajuan': tanggalPengajuan,
      'tanggal_mulai': tanggalMulai,
      'tanggal_akhir': tanggalAkhir,
      'status_validasi': statusValidasi,
      'keterangan': keterangan,
      'foto_bukti': fotoBukti,
      'sisa_kuota': sisaKuota,
      'year': year,
      'month': month,
      'alasan_penolakan': alasanPenolakan,
    };
  }

  // Method untuk menghitung durasi cuti dalam hari
  int getDurasiHari() {
    try {
      final mulai = DateTime.parse(tanggalMulai);
      final akhir = DateTime.parse(tanggalAkhir);
      return akhir.difference(mulai).inDays + 1; // +1 untuk include hari terakhir
    } catch (e) {
      return 0;
    }
  }

  // Method untuk format tanggal pengajuan
  String getFormattedTanggalPengajuan() {
    try {
      final date = DateTime.parse(tanggalPengajuan);
      final monthNames = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
    } catch (e) {
      return tanggalPengajuan;
    }
  }

  // Method untuk cek apakah cuti sudah disetujui
  bool get isApproved => statusValidasi == 'Approved';
  
  // Method untuk cek apakah cuti ditolak
  bool get isRejected => statusValidasi == 'Rejected';
  
  // Method untuk cek apakah cuti masih pending
  bool get isPending => statusValidasi == 'Pending';

  // Method untuk mendapatkan nama bulan
  String getMonthName() {
    const monthNames = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    if (month >= 1 && month <= 12) {
      return monthNames[month - 1];
    }
    return 'Unknown';
  }

  // Method untuk copy object dengan perubahan tertentu
  Cuti copyWith({
    int? idCuti,
    int? idKaryawan,
    String? kategori,
    String? tanggalPengajuan,
    String? tanggalMulai,
    String? tanggalAkhir,
    String? statusValidasi,
    String? keterangan,
    String? fotoBukti,
    int? sisaKuota,
    int? year,
    int? month,
    String? alasanPenolakan,
  }) {
    return Cuti(
      idCuti: idCuti ?? this.idCuti,
      idKaryawan: idKaryawan ?? this.idKaryawan,
      kategori: kategori ?? this.kategori,
      tanggalPengajuan: tanggalPengajuan ?? this.tanggalPengajuan,
      tanggalMulai: tanggalMulai ?? this.tanggalMulai,
      tanggalAkhir: tanggalAkhir ?? this.tanggalAkhir,
      statusValidasi: statusValidasi ?? this.statusValidasi,
      keterangan: keterangan ?? this.keterangan,
      fotoBukti: fotoBukti ?? this.fotoBukti,
      sisaKuota: sisaKuota ?? this.sisaKuota,
      year: year ?? this.year,
      month: month ?? this.month,
      alasanPenolakan: alasanPenolakan ?? this.alasanPenolakan,
    );
  }

  // Override toString untuk debugging
  @override
  String toString() {
    return 'Cuti(idCuti: $idCuti, kategori: $kategori, status: $statusValidasi, '
        'tanggal: $tanggalMulai - $tanggalAkhir)';
  }

  // Override equality operator
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Cuti && other.idCuti == idCuti;
  }

  @override
  int get hashCode => idCuti.hashCode;
}