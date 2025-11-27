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
  State<RiwayatCutiPage> createState() => _RiwayatCutiPageState(); // ← Ubah dari _RiwayatCutiPageState menjadi State<RiwayatCutiPage>
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

  Future<void> _initializeData() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    idKaryawan = prefs.getString('id_karyawan');

    if (token == null || idKaryawan == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token atau ID Karyawan tidak ditemukan, silakan login ulang')),
      );
      setState(() => isLoading = false);
      return;
    }
    await fetchBulanTahun();
  }

  Future<void> fetchBulanTahun() async {
    if (token == null || idKaryawan == null) return;

    final url = Uri.parse('${Config.apiUrl}/api/cuti/$idKaryawan/available_months');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List list = json.decode(response.body);
        List<String> newMonthOptions = ['Semua'];
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
        if (selectedMonth != null) {
          await fetchRiwayatCuti(selectedMonth!);
        }
      } else {
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
      setState(() => isLoading = false);
      return;
    }

    Uri url;
    if (bulanFormatted == 'Semua') {
      url = Uri.parse('${Config.apiUrl}/api/cuti/$idKaryawan');
    } else {
      final parts = bulanFormatted.split(' ');
      if (parts.length != 2) {
        setState(() => isLoading = false);
        return;
      }
      final month = _getMonthNumber(parts[0]);
      final year = parts[1];
      final bulan = "$year-${month.toString().padLeft(2, '0')}";
      url = Uri.parse('${Config.apiUrl}/api/cuti/$idKaryawan?bulan=$bulan');
    }

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        if (data is List) {
          setState(() {
            laporanList = List<Cuti>.from(data.map((item) => Cuti.fromJson(item)));
            isLoading = false;
          });
        } else {
          setState(() {
            laporanList = [];
            isLoading = false;
          });
        }
      } else {
        setState(() {
          laporanList = [];
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("[ERROR] fetchRiwayatCuti exception: $e");
      setState(() {
        laporanList = [];
        isLoading = false;
      });
    }
  }

  String _getMonthName(int monthNumber) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    if (monthNumber < 1 || monthNumber > 12) return '';
    return months[monthNumber - 1];
  }

  int _getMonthNumber(String monthName) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final idx = months.indexOf(monthName);
    return idx >= 0 ? idx + 1 : 0;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return const Color(0xFFFFA726);
      case 'Approved':
        return const Color(0xFF66BB6A);
      case 'Rejected':
        return const Color(0xFFEF5350);
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Pending':
        return Icons.hourglass_empty;
      case 'Approved':
        return Icons.check_circle;
      case 'Rejected':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2D3436), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Riwayat Cuti',
          style: TextStyle(
            color: Color(0xFF2D3436),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.grey[200],
            height: 1,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Section
          if (monthOptions.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04), // ← Fixed withOpacity
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C933F).withValues(alpha: 0.1), // ← Fixed withOpacity
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.tune,
                      color: Color(0xFF7C933F),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Periode',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF636E72),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedMonth,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D3436),
                          ),
                          items: monthOptions.map((String month) {
                            return DropdownMenuItem<String>(
                              value: month,
                              child: Text(month),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null && newValue != selectedMonth) {
                              setState(() => selectedMonth = newValue);
                              fetchRiwayatCuti(newValue);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Counter
          if (!isLoading && laporanList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${laporanList.length} Pengajuan',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF636E72),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // List Content
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF7C933F),
                    ),
                  )
                : laporanList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Belum Ada Riwayat Cuti',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Data pengajuan cuti akan muncul di sini',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFF7C933F),
                        onRefresh: () async {
                          await fetchBulanTahun();
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: laporanList.length,
                          itemBuilder: (context, index) {
                            final cuti = laporanList[index];
                            final tanggalPengajuan = DateFormat('dd MMM yyyy').format(
                              DateTime.parse(cuti.tanggalPengajuan),
                            );
                            final tanggalMulai = DateFormat('dd MMM yyyy').format(
                              DateTime.parse(cuti.tanggalMulai),
                            );
                            final tanggalAkhir = DateFormat('dd MMM yyyy').format(
                              DateTime.parse(cuti.tanggalAkhir),
                            );

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04), // ← Fixed withOpacity
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
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
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    cuti.kategori,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF2D3436),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.calendar_today,
                                                        size: 12,
                                                        color: Colors.grey[500],
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        tanggalPengajuan,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey[600],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(cuti.statusValidasi)
                                                    .withValues(alpha: 0.1), // ← Fixed withOpacity
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    _getStatusIcon(cuti.statusValidasi),
                                                    size: 14,
                                                    color: _getStatusColor(cuti.statusValidasi),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    cuti.statusValidasi,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: _getStatusColor(cuti.statusValidasi),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 16),

                                        // Periode
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF5F7FA),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Tanggal Mulai',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey[600],
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      tanggalMulai,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(0xFF2D3436),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                width: 1,
                                                height: 30,
                                                color: Colors.grey[300],
                                              ),
                                              Expanded(
                                                child: Padding(
                                                  padding: const EdgeInsets.only(left: 12),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Tanggal Akhir',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.grey[600],
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        tanggalAkhir,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w600,
                                                          color: Color(0xFF2D3436),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Keterangan
                                        if (cuti.keterangan != null && cuti.keterangan!.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[50],
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.blue[100]!,
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Icon(
                                                  Icons.info_outline,
                                                  size: 16,
                                                  color: Colors.blue[700],
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Keterangan',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: Colors.blue[700],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        cuti.keterangan!,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.blue[900],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],

                                        // ⭐ ALASAN PENOLAKAN
                                        if (cuti.statusValidasi == 'Rejected' &&
                                            cuti.alasanPenolakan != null &&
                                            cuti.alasanPenolakan!.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.red[50],
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.red[200]!,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Icon(
                                                  Icons.warning_amber_rounded,
                                                  size: 18,
                                                  color: Colors.red[700],
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Alasan Penolakan',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                          color: Colors.red[700],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        cuti.alasanPenolakan!,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.red[900],
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],

                                        // Button Detail
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton.icon(
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
                                              icon: const Icon(
                                                Icons.arrow_forward_ios,
                                                size: 12,
                                              ),
                                              label: const Text(
                                                'Lihat Detail',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              style: TextButton.styleFrom(
                                                foregroundColor: const Color(0xFF7C933F),
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
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