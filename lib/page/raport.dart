import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kebunsalak_app/config/config.dart';
import 'package:logger/logger.dart';

var logger = Logger();
class RaportPage extends StatefulWidget {
  const RaportPage({super.key});

  @override
  State<RaportPage> createState() => _RaportPageState();
}

class _RaportPageState extends State<RaportPage> {
  List<Map<String, dynamic>> absensiList = [];
  List<Map<String, dynamic>> cutiList = [];
  Map<String, List<Map<String, dynamic>>> absensiPerBulan = {}; 
  Map<String, List<Map<String, dynamic>>> cutiPerBulan = {}; 
  Map<String, int> totalCutiPerBulan = {}; 
  List<String> availableMonths = [];  
  bool isLoading = true;

  // Fungsi untuk mengambil data absensi dan cuti
  Future<void> fetchAbsensiAndCuti() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final idKaryawan = prefs.getString('id_karyawan');

    try {
      final absensiResponse = await http.get(
        Uri.parse('${Config.apiUrl}/api/absensi/history/$idKaryawan'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final cutiResponse = await http.get(
        Uri.parse('${Config.apiUrl}/api/cuti/$idKaryawan'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      debugPrint("Absensi Response status: ${absensiResponse.statusCode}");
      debugPrint("Cuti Response status: ${cutiResponse.statusCode}");

      if (absensiResponse.statusCode == 200 && cutiResponse.statusCode == 200) {
        final absensiData = jsonDecode(absensiResponse.body);
        final cutiData = jsonDecode(cutiResponse.body);

        setState(() {
          absensiList = List<Map<String, dynamic>>.from(absensiData);
          cutiList = List<Map<String, dynamic>>.from(cutiData);
          isLoading = false;
        });

        _separateDataByMonth(absensiList, cutiList);
      } else {
        setState(() {
          isLoading = false;
        });
        debugPrint("Failed to load data.");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data absensi dan cuti')),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      debugPrint("Error occurred: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
    }
  }

  // Fungsi untuk memisahkan absensi dan cuti per bulan
  void _separateDataByMonth(List<Map<String, dynamic>> absensiList, List<Map<String, dynamic>> cutiList) {
    Map<String, List<Map<String, dynamic>>> tempAbsensi = {};
    Map<String, List<Map<String, dynamic>>> tempCuti = {};

    for (var absensi in absensiList) {
      String month = _getMonthName(DateTime.parse(absensi['tanggal']).month);
      if (!tempAbsensi.containsKey(month)) {
        tempAbsensi[month] = [];
      }
      tempAbsensi[month]!.add(absensi);
    }

    for (var cuti in cutiList) {
      String month = _getMonthName(DateTime.parse(cuti['tanggal_mulai']).month);
      if (!tempCuti.containsKey(month)) {
        tempCuti[month] = [];
      }
      tempCuti[month]!.add(cuti);
    }

    Map<String, List<Map<String, dynamic>>> combinedData = {};

    tempAbsensi.forEach((month, absensiData) {
      if (!combinedData.containsKey(month)) {
        combinedData[month] = [];
      }
      combinedData[month]!.addAll(absensiData); 
    });

    tempCuti.forEach((month, cutiData) {
      if (!combinedData.containsKey(month)) {
        combinedData[month] = [];
      }
      combinedData[month]!.addAll(cutiData);
    });

    setState(() {
      absensiPerBulan = combinedData;
      cutiPerBulan = tempCuti;
      availableMonths = _getAvailableMonths(absensiPerBulan, cutiPerBulan);
      _calculateTotalCutiPerBulan(cutiPerBulan);
    });
  }

  List<String> _getAvailableMonths(Map<String, List<Map<String, dynamic>>> absensiPerBulan, Map<String, List<Map<String, dynamic>>> cutiPerBulan) {
    Set<String> months = {};

    absensiPerBulan.forEach((month, data) {
      months.add(month);
    });
    cutiPerBulan.forEach((month, data) {
      months.add(month);
    });

    return months.toList();
  }

  void _calculateTotalCutiPerBulan(Map<String, List<Map<String, dynamic>>> cutiPerBulan) {
    Map<String, int> totalCuti = {};

    cutiPerBulan.forEach((month, cutiData) {
      int totalDays = 0;

      for (var cuti in cutiData) {
        String tanggalMulai = cuti['tanggal_mulai'] ?? '';
        String tanggalAkhir = cuti['tanggal_akhir'] ?? '';
        String statusValidasi = cuti['status_validasi'] ?? '';

        if (tanggalMulai.isNotEmpty && tanggalAkhir.isNotEmpty && statusValidasi == 'Approved') {
          DateTime startDate = DateTime.parse(tanggalMulai);
          DateTime endDate = DateTime.parse(tanggalAkhir);
          totalDays += endDate.difference(startDate).inDays + 1;
        }
      }

      totalCuti[month] = totalDays;
    });

    setState(() {
      totalCutiPerBulan = totalCuti;
    });
  }

  String _getMonthName(int monthNumber) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[monthNumber - 1];
  }

  Widget buildRaportCard(String bulan) {
    if (!absensiPerBulan.containsKey(bulan) && !cutiPerBulan.containsKey(bulan)) {
      return const SizedBox();  
    }

    List<Map<String, dynamic>> combinedData = [];
    
    if (absensiPerBulan.containsKey(bulan)) {
      combinedData.addAll(absensiPerBulan[bulan]!);
    }
    if (cutiPerBulan.containsKey(bulan)) {
      combinedData.addAll(cutiPerBulan[bulan]!);
    }

    Map<String, int> kedisiplinan = calculateKedisiplinan(combinedData, cutiPerBulan[bulan] ?? []);
    int totalCuti = totalCutiPerBulan[bulan] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 6, 6, 6).withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              bulan, 
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildRow(Icons.check_circle, 'Hadir', kedisiplinan['kehadiran'].toString(), Colors.green),
          _buildRow(Icons.cancel, 'Terlambat', kedisiplinan['keterlambatan'].toString(), Colors.red),
          _buildRow(Icons.cancel, 'Pulang Sebelum Waktu', kedisiplinan['pulangLebihAwal'].toString(), Colors.red),
          _buildRow(Icons.beach_access, 'Total Cuti', totalCuti.toString(), Colors.orange),
          _buildRow(Icons.cancel, 'Tanpa Keterangan', kedisiplinan['tanpaKeterangan'].toString(), Colors.red),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E762F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 9),
              ),
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

  Widget _buildRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, int> calculateKedisiplinan(List<Map<String, dynamic>> absensiList, List<Map<String, dynamic>> cutiList) {
  int kehadiran = 0;
  int keterlambatan = 0;
  int pulangLebihAwal = 0;
  int tanpaKeterangan = 0;

  Set<String> daysWithInAbsensi = {};  // Menyimpan tanggal dengan absensi masuk (in)
  Set<String> daysWithOutAbsensi = {};  // Menyimpan tanggal dengan absensi keluar (out)
  Set<String> allDates = {};  // Menyimpan semua tanggal yang ada dalam absensi dan cuti

  // Jam masuk yang dijadwalkan
  final int scheduledHour = 8; // Jam 08:00
  final int scheduledMinute = 0; // Menit 00

  // Ambil bulan dan tahun saat ini
DateTime now = DateTime.now();
int currentYear = now.year;
int currentMonth = now.month;

// Tentukan bulan dan tahun untuk perhitungan
DateTime startDate = DateTime(currentYear, currentMonth, 1);  // Mulai bulan ini
DateTime endDate = DateTime(currentYear, currentMonth + 1, 0);  // Akhir bulan ini (0 untuk hari terakhir bulan)

// Tentukan nama bulan
List<String> monthNames = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
];

String monthName = monthNames[currentMonth - 1]; // Nama bulan berdasarkan nomor bulan saat ini

debugPrint("Start Date: $startDate");
debugPrint("End Date: $endDate");
debugPrint("Bulan: $monthName");  // Debug bulan saat ini

// Proses absensi dan cuti sesuai logika sebelumnya
// (kode Anda untuk menghitung absensi, keterlambatan, dan lainnya tetap sama)



  // Menyimpan tanggal absensi yang tercatat
  DateTime lastAbsensiDate = startDate; // Default tanggal pertama bulan ini

  // Menghitung absensi masuk dan keluar serta mencari tanggal absensi terakhir
  for (var absensi in absensiList) {
    String status = absensi['status'] ?? '';
    String tanggal = absensi['tanggal'] ?? '';
    String waktu = absensi['waktu'] ?? '';

    try {
      DateTime absensiDate = DateTime.parse(tanggal + ' ' + waktu); // Parsing tanggal + waktu
      allDates.add(tanggal); // Menyimpan semua tanggal absensi

      // Menyimpan tanggal absensi terakhir
      if (absensiDate.isAfter(lastAbsensiDate)) {
        lastAbsensiDate = absensiDate;
      }

      if (status == 'in') {
        // Menambahkan absensi masuk
        daysWithInAbsensi.add(tanggal);

        // Periksa keterlambatan dengan hanya membandingkan jam dan menit
        if (absensiDate.hour > scheduledHour || (absensiDate.hour == scheduledHour && absensiDate.minute > scheduledMinute)) {
          keterlambatan++;  // Jika lebih dari jam 08:00, dianggap terlambat
        }
      } else if (status == 'out') {
        // Menambahkan absensi keluar
        daysWithOutAbsensi.add(tanggal);

        // Periksa pulang lebih awal
        if (absensiDate.isBefore(DateTime(absensiDate.year, absensiDate.month, absensiDate.day, 17, 0))) {
          pulangLebihAwal++;  // Jika lebih awal dari jam 17:00, dianggap pulang lebih awal
        }
      }
    } catch (e) {
      continue;
    }
  }

  // Hanya menghitung Tanpa Keterangan untuk tanggal sebelum absensi terakhir yang tercatat
  for (var date = startDate; date.isBefore(lastAbsensiDate); date = date.add(Duration(days: 1))) {
    String tanggal = date.toIso8601String().split('T')[0]; // Mendapatkan tanggal dalam format YYYY-MM-DD

    bool isDateInCuti = false;
    bool isDateInAbsensi = false;

    // Cek apakah tanggal tersebut ada dalam rentang cuti yang disetujui
    for (var cuti in cutiList) {
      String statusCuti = cuti['status_validasi'] ?? '';
      String tanggalMulai = cuti['tanggal_mulai'] ?? '';
      String tanggalAkhir = cuti['tanggal_akhir'] ?? '';

      DateTime dateCuti = DateTime.parse(tanggal);
      DateTime startDate = DateTime.parse(tanggalMulai);
      DateTime endDate = DateTime.parse(tanggalAkhir);

      // Jika ada cuti yang disetujui pada tanggal ini, maka ini bukan "Tanpa Keterangan"
      if (statusCuti == 'Approved' && !dateCuti.isBefore(startDate) && !dateCuti.isAfter(endDate)) {
        isDateInCuti = true; // Tandai jika tanggal tersebut ada dalam cuti yang disetujui
        break;  // Jika ditemukan cuti yang disetujui, hentikan pengecekan lebih lanjut
      }
    }

    // Periksa apakah ada absensi masuk atau keluar untuk tanggal tersebut
    if (daysWithInAbsensi.contains(tanggal) || daysWithOutAbsensi.contains(tanggal)) {
      isDateInAbsensi = true;
    }

    // Jika tidak ada absensi dan cuti yang disetujui, tandai sebagai tanpa keterangan
    if (!isDateInCuti && !isDateInAbsensi) {
      debugPrint("Tanggal $tanggal: Tanpa Keterangan");
      tanpaKeterangan += 1; 
    }
  }

  // Menghitung kehadiran (tanggal yang memiliki absensi masuk dan keluar)
  kehadiran = daysWithInAbsensi.intersection(daysWithOutAbsensi).length;

  // Debug: Menampilkan hasil perhitungan
  debugPrint("Kehadiran: $kehadiran");
  debugPrint("Keterlambatan: $keterlambatan");
  debugPrint("Pulang Sebelum Waktu: $pulangLebihAwal");
  debugPrint("Tanpa Keterangan: $tanpaKeterangan");

  return {
    'kehadiran': kehadiran,
    'keterlambatan': keterlambatan,
    'pulangLebihAwal': pulangLebihAwal,
    'tanpaKeterangan': tanpaKeterangan,
  };
}

  @override
  void initState() {
    super.initState();
    fetchAbsensiAndCuti();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4ED),
  appBar: AppBar(
    backgroundColor: const Color(0xFFF4F4ED),
    elevation: 0,
    centerTitle: true,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.black),
      onPressed: () => Navigator.pop(context),
    ),
    title: const Text(
      'Raport',
      style: TextStyle(color: Colors.black),
    ),
  ),
  body: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),  // Menambahkan padding kiri dan kanan
      child: Column(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Expanded(
                  child: ListView.builder(
                    itemCount: availableMonths.length,
                    itemBuilder: (context, index) {
                      String month = availableMonths[index];
                      return buildRaportCard(month);
                    },
                  ),
                ),
        ],
      ),
    ),
  );
  }
}
