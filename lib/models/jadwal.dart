class Jadwal {
  final int idJadwal;
  final String tanggalJadwal;
  final String tugas;
  final String blokLahan;
  final int duration;
  final String tanggalSelesai;
  final DateTime createdAt;
  final DateTime updatedAt;

  Jadwal({
    required this.idJadwal,
    required this.tanggalJadwal,
    required this.tugas,
    required this.blokLahan,
    required this.duration,
    required this.tanggalSelesai,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Jadwal.fromJson(Map<String, dynamic> json) {
    return Jadwal(
      idJadwal: json['id_jadwal'] ?? json['id'] ?? 0,
      tanggalJadwal: json['tanggal_jadwal'] ?? '',
      tugas: json['tugas'] ?? '',
      blokLahan: json['blok_lahan'] ?? '',
      duration: json['duration'] ?? 0,
      tanggalSelesai: json['tanggal_selesai'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_jadwal': idJadwal,
      'tanggal_jadwal': tanggalJadwal,
      'tugas': tugas,
      'blok_lahan': blokLahan,
      'duration': duration,
      'tanggal_selesai': tanggalSelesai,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Getter untuk status jadwal
  String get status {
    try {
      final now = DateTime.now();
      final mulai = DateTime.parse(tanggalJadwal);
      final selesai = DateTime.parse(tanggalSelesai);

      if (now.isBefore(mulai)) {
        return 'Akan Datang';
      } else if (now.isAfter(selesai)) {
        return 'Selesai';
      } else {
        return 'Berlangsung';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  // Getter untuk progress percentage
  double get progressPercentage {
    try {
      final now = DateTime.now();
      final mulai = DateTime.parse(tanggalJadwal);
      final selesai = DateTime.parse(tanggalSelesai);

      if (now.isBefore(mulai)) return 0.0;
      if (now.isAfter(selesai)) return 100.0;

      final total = selesai.difference(mulai).inDays;
      final passed = now.difference(mulai).inDays;

      return (passed / total * 100).clamp(0.0, 100.0);
    } catch (e) {
      return 0.0;
    }
  }

  // Getter untuk sisa hari
  int get sisaHari {
    try {
      final now = DateTime.now();
      final selesai = DateTime.parse(tanggalSelesai);
      final diff = selesai.difference(now).inDays;
      return diff > 0 ? diff : 0;
    } catch (e) {
      return 0;
    }
  }

  // Method untuk format tanggal
  String formatTanggal(String tanggal) {
    try {
      final date = DateTime.parse(tanggal);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return tanggal;
    }
  }

  @override
  String toString() {
    return 'Jadwal(id: $idJadwal, tugas: $tugas, blok: $blokLahan, status: $status)';
  }
}