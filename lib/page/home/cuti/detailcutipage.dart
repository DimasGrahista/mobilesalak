import 'package:flutter/material.dart';
import 'package:kebunsalak_app/config/config.dart';
import 'package:logger/logger.dart';

class DetailCutiPage extends StatelessWidget {
  final String judul;
  final String uraian;
  final String status;
  final String tanggal;
  final String? foto;
  final String? tanggalMulai;
  final String? tanggalAkhir;
  final String? kategoriStatus;

  // Konstruktor menggunakan super.key untuk parameter 'key'
  const DetailCutiPage({
    super.key,  // Menyesuaikan dengan peringatan "use_super_parameters"
    required this.judul,
    required this.uraian,
    required this.status,
    required this.tanggal,
    this.foto,
    this.tanggalMulai,
    this.tanggalAkhir,
    this.kategoriStatus,
  });

  @override
  Widget build(BuildContext context) {
    // Gunakan 10.0.2.2 untuk emulator
    // final String baseUrl = 'http://10.0.2.2:8000/storage/cuti/';  // URL untuk Emulator
    final String baseUrl = '${Config.apiUrl}/storage/cuti/';  // URL untuk Emulator

    // Pastikan hanya satu folder 'cuti' di path
    final String imageUrl = (foto != null && foto!.isNotEmpty)
        ? '$baseUrl${foto?.replaceFirst('cuti/', '')}'  // Hapus 'cuti/' jika sudah ada
        : '';

    // Debug print URL gambar yang akan di-load
    var logger = Logger();
    logger.d('[DEBUG] Memuat gambar dari URL: $imageUrl');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pengajuan Cuti'),
        backgroundColor: const Color(0xFF7C933F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Judul: $judul',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('Status: $status', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            Text('Tanggal Pengajuan: $tanggal', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            // Menambahkan Tanggal Mulai dan Tanggal Akhir
            if (tanggalMulai != null && tanggalAkhir != null)
              Text(
                'Tanggal Mulai: $tanggalMulai\nTanggal Akhir: $tanggalAkhir',
                style: const TextStyle(fontSize: 16),
              ),
            const SizedBox(height: 10),
            // Menambahkan Kategori Status
            if (kategoriStatus != null)
              Text(
                'Kategori Status: $kategoriStatus',
                style: const TextStyle(fontSize: 16),
              ),
            const SizedBox(height: 10),
            Text('Uraian Kegiatan: $uraian', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            // Menampilkan gambar jika URL ada
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  height: 200,
                  width: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      return child;
                    } else {
                      return const CircularProgressIndicator();
                    }
                  },
                  errorBuilder: (context, error, stackTrace) {
                    logger.d('Error loading image: $error');
                    return const Icon(Icons.error);
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
