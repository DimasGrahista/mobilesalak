import 'package:flutter/material.dart';
import 'package:kebunsalak_app/config/config.dart';
import 'package:logger/logger.dart';

class DetailLaporPage extends StatelessWidget {
  final String judul;
  final String uraian;
  final String status;
  final String tanggal;
  final String? foto;

  const DetailLaporPage({
    super.key,
    required this.judul,
    required this.uraian,
    required this.status,
    required this.tanggal,
    this.foto,
  });

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = (foto != null && foto!.isNotEmpty)
        // ? 'http://10.0.2.2:8000/storage/$foto'
        ? '${Config.apiUrl}/storage/$foto'
        : null;

    // Debug print URL yang akan di-load
    var logger = Logger();
    logger.d('[DEBUG] Memuat gambar dari URL: $imageUrl');

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Laporan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Judul: $judul', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Tanggal: $tanggal'),
            const SizedBox(height: 8),
            Text('Status: $status'),
            const SizedBox(height: 8),
            Text('Uraian: $uraian'),
            const SizedBox(height: 12),
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                    if (loadingProgress == null) {
                      var logger = Logger();
                      logger.d('[DEBUG] Gambar selesai dimuat dari $imageUrl');
                      return child; // gambar sudah selesai dimuat
                    } else {
                      final progress = loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null;
                      var logger = Logger();
                      logger.d('[DEBUG] Gambar loading progress: ${(progress != null ? (progress * 100).toStringAsFixed(0) : "unknown")}% dari $imageUrl');

                      // tampilkan loading spinner atau teks saat loading
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              value: progress,
                            ),
                            const SizedBox(height: 8),
                            const Text('Sedang memuat gambar...'),
                          ],
                        ),
                      );
                    }
                  },
                  errorBuilder: (context, error, stackTrace) {
                    var logger = Logger();
                    logger.d('[ERROR] Gagal memuat gambar dari $imageUrl');
                    logger.d('[ERROR] Detail error: $error');
                    return const Center(child: Text('Gambar sedang di muat'));
                  },
                ),
              )
            else
              const Text('Tidak ada foto kegiatan'),
          ],
        ),
      ),
    );
  }
}
