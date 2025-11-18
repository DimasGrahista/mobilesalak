import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PenggajianPage extends StatefulWidget {
  const PenggajianPage({super.key});

  @override
  State<PenggajianPage> createState() => _PenggajianPageState();
}

class _PenggajianPageState extends State<PenggajianPage> {
  String nama = '';
  String jabatan = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      nama = prefs.getString('nama') ?? 'User';
      jabatan = prefs.getString('jabatan') ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4ED),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header dengan informasi user
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 24),
            decoration: const BoxDecoration(
              color: Color(0xFF5E762F),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, $nama 👋',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  jabatan,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // Daftar Gaji Bulanan
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: 12, // Untuk setiap bulan
              itemBuilder: (context, index) {
                return JadwalGajiCard(bulan: index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class JadwalGajiCard extends StatelessWidget {
  final int bulan;
  const JadwalGajiCard({super.key, required this.bulan});

  @override
  Widget build(BuildContext context) {
    // Mengambil data untuk bulan yang sesuai, ini hanya contoh data statis
    String bulanNama = '';
    double gajiPokok = 0;
    double bonus = 0;
    double potongan = 0;
    double totalGaji = 0;

    switch (bulan) {
      case 1: bulanNama = 'Januari'; gajiPokok = 5000000; bonus = 1000000; potongan = 50000; break;
      case 2: bulanNama = 'Februari'; gajiPokok = 5000000; bonus = 1100000; potongan = 20000; break;
      case 3: bulanNama = 'Maret'; gajiPokok = 5000000; bonus = 950000; potongan = 100000; break;
      // Tambahkan data untuk bulan lainnya
      default: bulanNama = 'Bulan $bulan'; gajiPokok = 5000000; bonus = 0; potongan = 0; break;
    }

    totalGaji = gajiPokok + bonus - potongan;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$bulanNama ${DateTime.now().year}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 24, thickness: 1),
          Row(
            children: [
              const Text('Gaji Pokok: '),
              Text(
                'Rp ${gajiPokok.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Row(
            children: [
              const Text('Bonus: '),
              Text(
                'Rp ${bonus.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Row(
            children: [
              const Text('Potongan: '),
              Text(
                'Rp ${potongan.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Total Gaji: ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Rp ${totalGaji.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6F8313),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.bottomRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6F8313),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              ),
              onPressed: () {
                // Aksi ketika tombol Print ditekan
              },
              child: const Text(
                'Print',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
