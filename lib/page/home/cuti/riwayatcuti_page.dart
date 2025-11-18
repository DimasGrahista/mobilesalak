import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/cuti.dart';
import 'detailcutipage.dart';
import 'package:kebunsalak_app/config/config.dart';

class RiwayatCutiPage extends StatefulWidget {
  const RiwayatCutiPage({super.key});

  @override
  _RiwayatCutiPageState createState() => _RiwayatCutiPageState();
}

class _RiwayatCutiPageState extends State<RiwayatCutiPage> {
  String? selectedMonth;
  List<String> monthOptions = [];
  List<Cuti> laporanList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchBulanTahun(); // Memanggil fungsi untuk mengambil bulan dan tahun yang memiliki data
  }

  // Mengambil bulan yang memiliki data
  Future<void> fetchBulanTahun() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final idKaryawan = prefs.getString('id_karyawan');  // Mengambil id_karyawan dari SharedPreferences

    // Menampilkan error jika token atau id_karyawan tidak ditemukan
    if (token == null || idKaryawan == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token atau ID Karyawan tidak ditemukan, silakan login ulang')),
      );
      setState(() {
        isLoading = false;
      });
      return;
    }

    final url = Uri.parse('${Config.apiUrl}/api/cuti/$idKaryawan/available_months'); // Endpoint yang mengembalikan bulan-bulan yang memiliki data

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      debugPrint("[DEBUG] Response Bulan-Tahun Status: ${response.statusCode}");
      debugPrint("[DEBUG] Response Bulan-Tahun Body: ${response.body}");

      if (response.statusCode == 200) {
        final List list = json.decode(response.body);
        List<String> newMonthOptions = [];

        for (var item in list) {
          try {
            final int bulan = item['month'];
            final int tahun = item['year'];
            final formatted = "${_getMonthName(bulan)} $tahun";
            newMonthOptions.add(formatted);
          } catch (e) {
            debugPrint("[ERROR] Gagal memproses item: $item => $e");
          }
        }

        setState(() {
          monthOptions = newMonthOptions;
          selectedMonth = monthOptions.isNotEmpty ? monthOptions[0] : null;
          laporanList = [];
          isLoading = false;
        });

        if (selectedMonth != null) {
          await fetchRiwayatCuti(selectedMonth!);  // Memanggil fungsi untuk mengambil laporan cuti berdasarkan bulan
        }
      } else {
        debugPrint("[ERROR] Gagal mengambil bulan-tahun: ${response.statusCode}");
        setState(() {
          monthOptions = [];
          selectedMonth = null;
          laporanList = [];
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("[ERROR] fetchBulanTahun exception: $e");
      setState(() {
        monthOptions = [];
        selectedMonth = null;
        laporanList = [];
        isLoading = false;
      });
    }
  }

  // Mengambil laporan berdasarkan bulan yang dipilih
  Future<void> fetchRiwayatCuti(String bulanFormatted) async {
  setState(() {
    isLoading = true;
    laporanList = [];
  });

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');  // Pastikan token ada di SharedPreferences
  final idKaryawan = prefs.getString('id_karyawan');  // Pastikan id_karyawan ada

  if (token == null || idKaryawan == null) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Token atau ID Karyawan tidak ditemukan, silakan login ulang')),
    );
    setState(() {
      isLoading = false;
    });
    return;
  }

  // Memastikan bulan yang diterima dalam format yang benar
  final parts = bulanFormatted.split(' ');
  if (parts.length != 2) {
    debugPrint("[ERROR] Format bulan tidak valid: $bulanFormatted");
    setState(() => isLoading = false);
    return;
  }

  final month = _getMonthNumber(parts[0]);
  final year = parts[1];
  final bulan = "$year-${month.toString().padLeft(2, '0')}";

  final url = Uri.parse('${Config.apiUrl}/api/cuti/$idKaryawan?bulan=$bulan');  // Memastikan id_karyawan diteruskan

  try {
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',  // Pastikan token ada di header Authorization
        'Accept': 'application/json',
      },
    );

    debugPrint("[DEBUG] Response Riwayat Cuti Status: ${response.statusCode}");
    debugPrint("[DEBUG] Response Riwayat Cuti Body: ${response.body}");

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      setState(() {
        laporanList = List<Cuti>.from(data.map((item) => Cuti.fromJson(item)));
        isLoading = false;
      });
    } else {
      debugPrint("[ERROR] Gagal mengambil riwayat cuti. Kode: ${response.statusCode}");
      setState(() {
        laporanList = [];
        isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil riwayat cuti. Kode: ${response.statusCode}')),
      );
    }
  } catch (e) {
    debugPrint("[ERROR] fetchRiwayatCuti exception: $e");
    setState(() {
      laporanList = [];
      isLoading = false;
    });
  }
}




  // Fungsi untuk mendapatkan nama bulan dari nomor bulan
  String _getMonthName(int monthNumber) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    if (monthNumber < 1 || monthNumber > 12) return '';
    return months[monthNumber - 1];
  }

  // Fungsi untuk mendapatkan nomor bulan dari nama bulan
  int _getMonthNumber(String monthName) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final idx = months.indexOf(monthName);
    return idx >= 0 ? idx + 1 : 0;
  }

  // Fungsi untuk menentukan warna status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.yellow;
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.black; // Default color for unknown status
    }
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
          'Cek Cuti',
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
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      items: monthOptions.map((String month) {
                        return DropdownMenuItem<String>(
                          value: month,
                          child: Text(month, style: const TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null && newValue != selectedMonth) {
                          setState(() {
                            selectedMonth = newValue;
                            laporanList = [];
                            isLoading = true;
                          });
                          fetchRiwayatCuti(newValue);
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
                : laporanList.isEmpty
                    ? const Center(child: Text('Tidak ada data riwayat cuti'))
                    : ListView.builder(
                        itemCount: laporanList.length,
                        itemBuilder: (context, index) {
                          final cuti = laporanList[index];
                          final tanggalPengajuan = DateFormat('dd/MM/yyyy').format(
                            DateTime.parse(cuti.tanggalPengajuan),
                          );

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cuti.kategori,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Text("Status: ", style: TextStyle(fontWeight: FontWeight.w500)),
                                      const SizedBox(width: 8),
                                      Text(
                                        cuti.statusValidasi,
                                        style: TextStyle(
                                          color: _getStatusColor(cuti.statusValidasi),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text("Tanggal Pengajuan: $tanggalPengajuan"),
                                  const SizedBox(height: 4),
                                  Text("Tanggal Mulai: ${cuti.tanggalMulai}"),
                                  const SizedBox(height: 4),
                                  Text("Tanggal Akhir: ${cuti.tanggalAkhir}"),
                                  const SizedBox(height: 8),
                                  if (cuti.keterangan != null) Text("Keterangan: ${cuti.keterangan}"),
                                  const SizedBox(height: 8),
                                  // Button for Detail Pengajuan Cuti
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF7C933F),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      onPressed: () {
                                        // Menambahkan sedikit delay sebelum navigasi
                                        Future.delayed(const Duration(milliseconds: 100), () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => DetailCutiPage(
                                                judul: cuti.kategori,
                                                uraian: cuti.keterangan ?? 'Tidak ada keterangan', // Mengirimkan data cuti
                                                status: cuti.statusValidasi,
                                                tanggal: cuti.tanggalPengajuan,
                                                foto: cuti.fotoBukti,
                                                tanggalMulai: cuti.tanggalMulai,
                                                tanggalAkhir: cuti.tanggalAkhir,
                                              ),
                                            ),
                                          );
                                        });
                                      },
                                      child: const Text(
                                        'Detail Pengajuan Cuti',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
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
