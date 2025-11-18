import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kebunsalak_app/config/config.dart';

class RiwayatAbsensiPage extends StatefulWidget {
  const RiwayatAbsensiPage({super.key});

  @override
  State<RiwayatAbsensiPage> createState() => _RiwayatAbsensiPageState();
}

class _RiwayatAbsensiPageState extends State<RiwayatAbsensiPage> {
  List<Map<String, String>> absensiList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAllData();
  }

  // Fungsi untuk mengambil data cuti dan absensi secara paralel
  Future<void> fetchAllData() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final idKaryawan = prefs.getString('id_karyawan');

    try {
      // Mengambil data cuti dan absensi secara paralel`
      final cutiResponse = http.get(
        Uri.parse('${Config.apiUrl}/api/cuti/$idKaryawan'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final absensiResponse = http.get(
        Uri.parse('${Config.apiUrl}/api/absensi/history'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      // Menunggu kedua request selesai
      final responses = await Future.wait([cutiResponse, absensiResponse]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final cutiData = jsonDecode(responses[0].body);
        final absensiData = jsonDecode(responses[1].body);

        List<Map<String, String>> tempList = [];

        Map<String, Map<String, String>> groupedAbsensi = {};

        // Proses data cuti
        for (var item in cutiData) {
          String tanggalMulai = item['tanggal_mulai'] ?? '';
          String tanggalAkhir = item['tanggal_akhir'] ?? '';
          if (tanggalMulai.isNotEmpty && tanggalAkhir.isNotEmpty) {
            DateTime startDate = DateTime.parse(tanggalMulai);
            DateTime endDate = DateTime.parse(tanggalAkhir);
            for (DateTime date = startDate; date.isBefore(endDate.add(Duration(days: 1))); date = date.add(Duration(days: 1))) {
              tempList.add({
                'day': date.day.toString(),
                'month': _getMonthName(date.month),
                'year': date.year.toString(),
                'scanIn': 'Cuti',
                'scanOut': 'Cuti',
                'status': 'Cuti',
              });
            }
          }
        }

        // Mengelompokkan Absensi berdasarkan tanggal
        for (var item in absensiData['data']) {
          String tanggal = item['tanggal'] ?? '';
          String waktuMasuk = item['waktu'];
          String waktuKeluar = item['waktu'];
          String status = item['status'] ?? '';

          if (tanggal.isNotEmpty) {
            DateTime absensiDate = DateTime.parse(tanggal);
            String formattedDate = _formatDate(absensiDate);

            if (!groupedAbsensi.containsKey(formattedDate)) {
              groupedAbsensi[formattedDate] = {
                'day': absensiDate.day.toString(),
                'month': _getMonthName(absensiDate.month),
                'year': absensiDate.year.toString(),
                'scanIn': '', // Defaultkan ke kosong
                'scanOut': '', // Defaultkan ke kosong
                'status': 'Absensi',
              };
            }

            // Menangani status 'in' dan 'out'
            if (status == 'in') {
              groupedAbsensi[formattedDate]?['scanIn'] = waktuMasuk;  // Gunakan string default
            } else if (status == 'out') {
              groupedAbsensi[formattedDate]?['scanOut'] = waktuKeluar;  // Gunakan string default
            }
          }
        }

        // Masukkan absensi yang dikelompokkan ke dalam tempList
        tempList.addAll(groupedAbsensi.values);

        setState(() {
          absensiList = tempList;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data')),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
    }
  }

  // Fungsi untuk format tanggal menjadi YYYY-MM-DD
  String _formatDate(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-${(date.month).toString().padLeft(2, '0')}-${(date.day).toString().padLeft(2, '0')}";
  }

  // Fungsi untuk mengubah nomor bulan menjadi nama bulan
  String _getMonthName(int monthNumber) {
    const months = [
      'Januari', 'Febuari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[monthNumber - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C933F),
        title: const Text('Riwayat Absensi', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: absensiList.length,
              itemBuilder: (context, index) {
                var item = absensiList[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Row(
                      children: [
                        Column(
                          children: [
                            Text(item['day']!, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            Text(item['month']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(item['year']!, style: const TextStyle(fontSize: 12, color: Color.fromARGB(255, 0, 0, 0))),
                          ],
                        ),
                        const VerticalDivider(width: 19, thickness: 1, color: Colors.grey),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Cek jika status adalah 'Cuti', hanya tampilkan satu teks "Cuti"
                              if (item['status'] == 'Cuti') 
                                Text(
                                  'Cuti', 
                                  style: TextStyle(
                                    color: Colors.orange, 
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 18,  // Menambahkan ukuran font yang lebih besar
                                  ),
                                ),
                              // Jika status adalah 'Absensi', tampilkan Scan-in dan Scan-out
                              if (item['status'] == 'Absensi') 
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Cek jika status adalah 'Absensi', tampilkan Scan-in dan Scan-out sejajar secara horizontal
                                    if (item['status'] == 'Absensi')
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        children: [
                                          // Scan In
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Scan In', style: TextStyle(color: Colors.grey)),
                                              Text(
                                                item['scanIn']!,
                                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 36), // Jarak antara Scan In dan Scan Out
                                          // Scan Out
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Scan Out', style: TextStyle(color: Colors.grey)),
                                              Text(
                                                item['scanOut']!,
                                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                  ]
                                ),
                            ]
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
