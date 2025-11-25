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
  String? idKaryawan;
  String? token;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  // Inisialisasi data dan ambil token + id_karyawan
  Future<void> _initializeData() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    idKaryawan = prefs.getString('id_karyawan');

    debugPrint("[DEBUG] Token: $token");
    debugPrint("[DEBUG] ID Karyawan: $idKaryawan");

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

    // Ambil bulan yang tersedia
    await fetchBulanTahun();
  }

  // Mengambil bulan yang memiliki data cuti
  Future<void> fetchBulanTahun() async {
    if (token == null || idKaryawan == null) return;

    final url = Uri.parse('${Config.apiUrl}/api/cuti/$idKaryawan/available_months');
    
    debugPrint("[DEBUG] Fetching available months from: $url");

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
        List<String> newMonthOptions = ['Semua']; // Tambahkan opsi "Semua"

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
          isLoading = false;
        });

        // Ambil semua riwayat cuti (tanpa filter bulan)
        if (selectedMonth != null) {
          await fetchRiwayatCuti(selectedMonth!);
        }
      } else if (response.statusCode == 404) {
        // Tidak ada data bulan, tapi tetap tampilkan opsi "Semua"
        setState(() {
          monthOptions = ['Semua'];
          selectedMonth = 'Semua';
          isLoading = false;
        });
        await fetchRiwayatCuti('Semua');
      } else {
        debugPrint("[ERROR] Gagal mengambil bulan-tahun: ${response.statusCode}");
        setState(() {
          monthOptions = ['Semua'];
          selectedMonth = 'Semua';
          isLoading = false;
        });
        await fetchRiwayatCuti('Semua');
      }
    } catch (e) {
      debugPrint("[ERROR] fetchBulanTahun exception: $e");
      setState(() {
        monthOptions = ['Semua'];
        selectedMonth = 'Semua';
        isLoading = false;
      });
      await fetchRiwayatCuti('Semua');
    }
  }

  // Mengambil riwayat cuti berdasarkan bulan yang dipilih
  Future<void> fetchRiwayatCuti(String bulanFormatted) async {
    setState(() {
      isLoading = true;
      laporanList = [];
    });

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

    Uri url;

    // Jika pilih "Semua", ambil semua data tanpa filter bulan
    if (bulanFormatted == 'Semua') {
      url = Uri.parse('${Config.apiUrl}/api/cuti/$idKaryawan');
      debugPrint("[DEBUG] Fetching all cuti from: $url");
    } else {
      // Parse bulan dan tahun dari format "Januari 2025"
      final parts = bulanFormatted.split(' ');
      if (parts.length != 2) {
        debugPrint("[ERROR] Format bulan tidak valid: $bulanFormatted");
        setState(() => isLoading = false);
        return;
      }

      final month = _getMonthNumber(parts[0]);
      final year = parts[1];
      final bulan = "$year-${month.toString().padLeft(2, '0')}";

      url = Uri.parse('${Config.apiUrl}/api/cuti/$idKaryawan?bulan=$bulan');
      debugPrint("[DEBUG] Fetching cuti with filter from: $url");
    }

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      debugPrint("[DEBUG] Response Riwayat Cuti Status: ${response.statusCode}");
      debugPrint("[DEBUG] Response Riwayat Cuti Body: ${response.body}");

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        
        // Handle jika response adalah array
        if (data is List) {
          setState(() {
            laporanList = List<Cuti>.from(data.map((item) => Cuti.fromJson(item)));
            isLoading = false;
          });
          debugPrint("[DEBUG] Berhasil load ${laporanList.length} data cuti");
        } else {
          setState(() {
            laporanList = [];
            isLoading = false;
          });
        }
      } else if (response.statusCode == 404) {
        // Tidak ada data
        debugPrint("[INFO] Tidak ada data cuti untuk filter ini");
        setState(() {
          laporanList = [];
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
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

  // Fungsi untuk menentukan warna status (TETAP DIPERTAHANKAN)
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.yellow;
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.black;
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
          'Riwayat Cuti',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter Bulan (Dropdown)
          if (monthOptions.isNotEmpty)
            Container(
              color: const Color(0xFF7C933F),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'Filter Bulan:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<String>(
                      value: selectedMonth,
                      dropdownColor: const Color(0xFF7C933F),
                      iconEnabledColor: Colors.white,
                      underline: Container(),
                      isExpanded: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      items: monthOptions.map((String month) {
                        return DropdownMenuItem<String>(
                          value: month,
                          child: Text(
                            month,
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null && newValue != selectedMonth) {
                          setState(() {
                            selectedMonth = newValue;
                          });
                          fetchRiwayatCuti(newValue);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Info jumlah data
          if (!isLoading && laporanList.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey[100],
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Ditemukan ${laporanList.length} pengajuan cuti',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

          // List Riwayat Cuti
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : laporanList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ada data riwayat cuti',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await fetchBulanTahun();
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
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
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            cuti.kategori,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(cuti.statusValidasi).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: _getStatusColor(cuti.statusValidasi),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Text(
                                            cuti.statusValidasi,
                                            style: TextStyle(
                                              color: _getStatusColor(cuti.statusValidasi),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Pengajuan: $tanggalPengajuan",
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.date_range, size: 16, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Mulai: ${cuti.tanggalMulai}",
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.event, size: 16, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Akhir: ${cuti.tanggalAkhir}",
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    if (cuti.keterangan != null && cuti.keterangan!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.notes, size: 16, color: Colors.grey),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              "Keterangan: ${cuti.keterangan}",
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF7C933F),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.visibility,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Detail',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => DetailCutiPage(
                                                judul: cuti.kategori,
                                                uraian: cuti.keterangan ?? 'Tidak ada keterangan',
                                                status: cuti.statusValidasi,
                                                tanggal: cuti.tanggalPengajuan,
                                                foto: cuti.fotoBukti,
                                                tanggalMulai: cuti.tanggalMulai,
                                                tanggalAkhir: cuti.tanggalAkhir,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}