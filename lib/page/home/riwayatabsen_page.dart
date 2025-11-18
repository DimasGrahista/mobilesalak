import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kebunsalak_app/config/config.dart';
import 'package:logger/logger.dart';

class RiwayatAbsensiPage extends StatefulWidget {
  const RiwayatAbsensiPage({super.key});

  @override
  State<RiwayatAbsensiPage> createState() => _RiwayatAbsensiPageState();
}

class _RiwayatAbsensiPageState extends State<RiwayatAbsensiPage> {
  List<Map<String, String>> absensiList = [];
  List<Map<String, String>> filteredAbsensiList = [];
  List<String> availableMonths = []; // List bulan yang ada dalam data
  bool isLoading = true;
  String selectedMonth = ''; // Default bulan kosong
  bool isCutiDataAvailable = false; // Flag untuk memeriksa data cuti

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

    // // Debugging untuk memeriksa token dan id_karyawan
    // print("Token: $token");
    // print("ID Karyawan: $idKaryawan");
    

    var logger = Logger();

    // Ganti print dengan logger
    logger.d("Token: $token");
    logger.d("ID Karyawan: $idKaryawan");

    try {
      // Mengambil data cuti dan absensi secara paralel
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
      var logger = Logger();

      logger.d("Cuti Response Status: ${responses[0].statusCode}");
      logger.d("Absensi Response Status: ${responses[1].statusCode}");

      logger.d("Cuti Response Body: ${responses[0].body}");
      logger.d("Absensi Response Body: ${responses[1].body}");

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final cutiData = jsonDecode(responses[0].body);
        final absensiData = jsonDecode(responses[1].body);

        // Debugging untuk memeriksa data yang diterima
        logger.d("Cuti Data: $cutiData");
        logger.d("Absensi Data: $absensiData");

        List<Map<String, String>> tempList = [];
        Map<String, Map<String, String>> groupedAbsensi = {};

        // Memproses data absensi terlebih dahulu
        processAbsensiData(absensiData['data'], groupedAbsensi);

        // Cek apakah data cuti ada atau tidak
        if (cutiData.isEmpty) {
          logger.d("Data cuti kosong");
          setState(() {
            isCutiDataAvailable = false; // Jika data cuti kosong, set flag ke false
          });
        } else {
          logger.d("Data cuti berhasil dimuat");
          isCutiDataAvailable = true; // Jika data cuti ada, set flag ke true
        }

        // **Proses data cuti setelah data absensi** hanya jika ada data cuti
        if (isCutiDataAvailable) {
          processCutiData(cutiData, tempList);
        }

        // Masukkan absensi yang dikelompokkan ke dalam tempList
        tempList.addAll(groupedAbsensi.values);

        // Urutkan berdasarkan tanggal dari yang terbaru (terbesar) ke yang terlama (terkecil)
        tempList.sort((a, b) {
          String monthA = a['month'] ?? 'Januari';  // Default ke Januari jika bulan null
          String monthB = b['month'] ?? 'Januari';  // Default ke Januari jika bulan null
          String dayA = a['day'] ?? '01';  // Default ke '01' jika day null
          String dayB = b['day'] ?? '01';  // Default ke '01' jika day null
          
          // Pastikan bulan dan hari selalu memiliki dua digit
          String formattedMonthA = _getMonthNumber(monthA).toString().padLeft(2, '0');
          String formattedMonthB = _getMonthNumber(monthB).toString().padLeft(2, '0');
          String formattedDayA = dayA.padLeft(2, '0');
          String formattedDayB = dayB.padLeft(2, '0');
          
          DateTime dateA = DateTime.parse("${a['year']}-${formattedMonthA}-${formattedDayA}");
          DateTime dateB = DateTime.parse("${b['year']}-${formattedMonthB}-${formattedDayB}");
          
          return dateB.compareTo(dateA); // Urutkan dari yang terbaru ke yang terlama
        });

        // Setel bulan yang pertama kali muncul sebagai default
        selectedMonth = availableMonths.isNotEmpty ? availableMonths.first : '';

        setState(() {
          absensiList = tempList;
          filteredAbsensiList = filterByMonth(selectedMonth); // Filter data berdasarkan bulan yang dipilih
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        var logger = Logger();
        // Jika tidak ada data cuti atau absensi, tampilkan pesan
        logger.d("Gagal memuat data atau data kosong.");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data atau data kosong.')),
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

  // Fungsi untuk memproses data cuti
  void processCutiData(List<dynamic> cutiData, List<Map<String, String>> tempList) {
    if (cutiData.isNotEmpty) {
      var logger = Logger();
      logger.d("Memproses data cuti...");
      for (var item in cutiData) {
        if (item['status_validasi'] == 'Approved') {
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
              // Tambahkan bulan ke dalam daftar bulan yang tersedia
              if (!availableMonths.contains(_getMonthName(date.month))) {
                availableMonths.add(_getMonthName(date.month));
              }
            }
          }
        }
      }
    } else {
      var logger = Logger();
      logger.d("Tidak ada data cuti.");
    }
  }

  // Fungsi untuk memproses data absensi
  void processAbsensiData(List<dynamic> absensiData, Map<String, Map<String, String>> groupedAbsensi) {
    if (absensiData.isNotEmpty) {
      var logger = Logger();
      logger.d("Memproses data absensi...");
      for (var item in absensiData) {
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
            groupedAbsensi[formattedDate]?['scanIn'] = waktuMasuk;
          } else if (status == 'out') {
            groupedAbsensi[formattedDate]?['scanOut'] = waktuKeluar;
          }
          // Tambahkan bulan ke dalam daftar bulan yang tersedia
          if (!availableMonths.contains(_getMonthName(absensiDate.month))) {
            availableMonths.add(_getMonthName(absensiDate.month));
          }
        }
      }
    } else {
      var logger = Logger();
      logger.d("Tidak ada data absensi.");
    }
  }

  // Fungsi untuk memfilter data berdasarkan bulan yang dipilih
  List<Map<String, String>> filterByMonth(String month) {
    return absensiList.where((item) {
      return item['month'] == month;
    }).toList();
  }

  // Fungsi untuk format tanggal menjadi YYYY-MM-DD
  String _formatDate(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  // Fungsi untuk mengubah nomor bulan menjadi nama bulan
  String _getMonthName(int monthNumber) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[monthNumber - 1];
  }

  // Fungsi untuk mengubah nama bulan menjadi nomor bulan
  int _getMonthNumber(String monthName) {
    const months = {
      'Januari': 1, 'Februari': 2, 'Maret': 3, 'April': 4, 'Mei': 5, 'Juni': 6,
      'Juli': 7, 'Agustus': 8, 'September': 9, 'Oktober': 10, 'November': 11, 'Desember': 12
    };
    return months[monthName] ?? 1; // Default ke Januari jika bulan tidak ditemukan
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
      body: Column(
        children: [
          // Dropdown untuk memilih bulan, hanya bulan yang ada dalam data
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 35),
            child: Row(
              children: [
                // Dropdown di sebelah kiri atas
                DropdownButton<String>( 
                  value: selectedMonth.isEmpty ? null : selectedMonth,
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedMonth = newValue!; // Set bulan yang dipilih
                      filteredAbsensiList = filterByMonth(selectedMonth); // Filter ulang data
                    });
                  },
                  items: availableMonths.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          // Tampilan absensi yang sudah difilter berdasarkan bulan
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Expanded(
                  child: ListView.builder(
                    itemCount: filteredAbsensiList.length,
                    itemBuilder: (context, index) {
                      var item = filteredAbsensiList[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        color: item['status'] == 'Cuti'
                            ? const Color.fromARGB(255, 255, 231, 195) // Warna untuk Cuti
                            : item['status'] == 'Absensi'
                                ? const Color.fromARGB(255, 206, 233, 207) // Warna untuk Absensi
                                : Colors.white, // Warna default jika status tidak ditemukan
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
                                    if (item['status'] == 'Cuti')
                                      Text(
                                        'Cuti',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    if (item['status'] == 'Absensi')
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Scan In', style: TextStyle(color: Color.fromARGB(255, 0, 0, 0))),
                                              Text(
                                                item['scanIn'] ?? 'Tidak Ada Data',
                                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 36),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Scan Out', style: TextStyle(color: Colors.grey)),
                                              Text(
                                                item['scanOut'] ?? 'Tidak Ada Data',
                                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}
