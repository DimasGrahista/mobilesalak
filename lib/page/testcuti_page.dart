import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kebunsalak_app/config/config.dart';
import 'package:logger/logger.dart';

var logger = Logger();
class TestcutiPage extends StatefulWidget {
  const TestcutiPage({super.key});

  @override
  State<TestcutiPage> createState() => _TestcutiPageState();
}

class _TestcutiPageState extends State<TestcutiPage> {
  String? selectedMonth;
  List<String> monthOptions = [];
  List<Map<String, String>> cutiList = [];
  List<Map<String, String>> fullCutiList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCuti();
  }

  // Fungsi untuk mengambil data cuti dan mengonversi bulan ke angka bulan
  Future<void> fetchCuti() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final idKaryawan = prefs.getString('id_karyawan');

    final cutiUrl = Uri.parse('${Config.apiUrl}/api/cuti/$idKaryawan');

    try {
      final cutiResponse = await http.get(
        cutiUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (cutiResponse.statusCode == 200) {
        final cutiData = jsonDecode(cutiResponse.body);
        logger.d('Cuti Data: $cutiData'); // Log untuk memeriksa data cuti yang diterima

        Map<String, Map<String, String>> tempCuti = {};
        Set<String> bulanSet = {};

        // Loop untuk menambahkan data cuti
        for (var item in cutiData) {
          String tanggalMulai = item['tanggal_mulai'] ?? '';
          String tanggalAkhir = item['tanggal_akhir'] ?? '';

          if (tanggalMulai.isNotEmpty && tanggalAkhir.isNotEmpty) {
            DateTime startDate = DateTime.parse(tanggalMulai);
            DateTime endDate = DateTime.parse(tanggalAkhir);

            // Menambahkan tanggal-tanggal cuti ke dalam cutiDates
            for (DateTime date = startDate; date.isBefore(endDate.add(Duration(days: 1))); date = date.add(Duration(days: 1))) {
              String formattedDay = date.day.toString().padLeft(2, '0');
              String formattedMonth = _getMonthName(date.month);
              String formattedYear = date.year.toString();

              if (!tempCuti.containsKey(formattedDay)) {
                tempCuti[formattedDay] = {
                  'day': formattedDay,
                  'month': formattedMonth,
                  'year': formattedYear,
                };
              }
              bulanSet.add("$formattedMonth $formattedYear");
            }
          }
        }

        fullCutiList = tempCuti.values.toList();

        monthOptions = bulanSet.toList()..sort((a, b) => b.compareTo(a));
        selectedMonth = monthOptions.isNotEmpty ? monthOptions[0] : null;

        filterCutiByMonth();
      } else {
        setState(() => isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data cuti: ${cutiResponse.statusCode}')),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan mengambil data cuti: $e')),
      );
    }
  }

  // Fungsi filter cuti berdasarkan bulan yang dipilih
  void filterCutiByMonth() {
    if (selectedMonth == null) {
      setState(() {
        cutiList = [];
        isLoading = false;
      });
      return;
    }

    List<String> split = selectedMonth!.split(' '); // Menggunakan format year-month
    String selectedMonthName = split[0];
    String selectedYear = split[1];

    List<Map<String, String>> filtered = fullCutiList.where((item) {
      return item['month'] == selectedMonthName && item['year'] == selectedYear;
    }).toList();

    // Sort descending
    filtered.sort((a, b) {
      DateTime dateA = DateTime.parse('${a['year']!}-${_getMonthNumber(a['month']!).toString().padLeft(2, '0')}-${a['day']!}');
      DateTime dateB = DateTime.parse('${b['year']!}-${_getMonthNumber(b['month']!).toString().padLeft(2, '0')}-${b['day']!}');
      return dateB.compareTo(dateA);
    });

    setState(() {
      cutiList = filtered;
      isLoading = false;
    });
  }

  String _getMonthName(int monthNumber) {
    const months = [
      'Januari', 'Febuari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[monthNumber - 1];
  }

  int _getMonthNumber(String monthName) {
    const months = [
      'Januari', 'Febuari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months.indexOf(monthName) + 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text(
          'Riwayat Cuti',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (monthOptions.isNotEmpty)
            Container(
              color: const Color(0xFF7C933F),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      value: selectedMonth,
                      dropdownColor: const Color(0xFF7C933F),
                      iconEnabledColor: Colors.white,
                      underline: Container(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      items: monthOptions.map((String month) {
                        return DropdownMenuItem<String>(
                          value: month,
                          child: Text(month, style: const TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedMonth = newValue;
                          });
                          filterCutiByMonth();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : fullCutiList.isEmpty
                    ? const Center(child: Text('Anda belum mengajukan cuti.'))
                    : cutiList.isEmpty
                        ? const Center(child: Text('Tidak ada cuti pada bulan ini.'))
                        : ListView.builder(
                            itemCount: cutiList.length,
                            itemBuilder: (context, index) {
                              var item = cutiList[index];
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
                                          Text(item['year']!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                                      const VerticalDivider(width: 24, thickness: 1, color: Colors.grey),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Status', style: TextStyle(color: Colors.grey)),
                                            Text('Cuti', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
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
