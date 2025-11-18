import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kebunsalak_app/page/home/detail_laporan_page.dart';
import 'package:kebunsalak_app/config/config.dart';

class RiwayatLaporPage extends StatefulWidget {
  const RiwayatLaporPage({super.key});

  @override
  RiwayatLaporPageState createState() => RiwayatLaporPageState();
}

class RiwayatLaporPageState extends State<RiwayatLaporPage> {
  List laporanList = [];
  List laporanListFiltered = [];
  bool isLoading = true;
  String? idKaryawan;
  
  // Filter variables
  String selectedFilter = 'Semua';
  DateTime? customStartDate;
  DateTime? customEndDate;

  @override
  void initState() {
    super.initState();
    _loadIdKaryawan();
  }

  Future<void> _loadIdKaryawan() async {
    final prefs = await SharedPreferences.getInstance();
    idKaryawan = prefs.getString('id_karyawan');
    debugPrint("[DEBUG] ID Karyawan: $idKaryawan");

    if (idKaryawan != null && idKaryawan!.isNotEmpty) {
      fetchLaporan();
    } else {
      debugPrint("[ERROR] ID Karyawan tidak ditemukan");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchLaporan() async {
    if (idKaryawan == null || idKaryawan!.isEmpty) {
      debugPrint("[ERROR] ID Karyawan kosong");
      return;
    }

    setState(() {
      isLoading = true;
    });

    final url = Uri.parse('${Config.apiUrl}/api/laporan?id_karyawan=$idKaryawan');

    try {
      debugPrint("[DEBUG] URL fetchLaporan: $url");

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      debugPrint("[DEBUG] Response status: ${response.statusCode}");
      debugPrint("[DEBUG] Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          laporanList = data;
          _applyFilter();
          isLoading = false;
        });
      } else {
        debugPrint("[ERROR] Gagal mengambil laporan: ${response.statusCode}");
        setState(() {
          laporanList = [];
          laporanListFiltered = [];
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("[ERROR] fetchLaporan exception: $e");
      setState(() {
        laporanList = [];
        laporanListFiltered = [];
        isLoading = false;
      });
    }
  }

  void _applyFilter() {
    if (selectedFilter == 'Semua') {
      laporanListFiltered = List.from(laporanList);
    } else if (selectedFilter == 'Hari Ini') {
      final today = DateTime.now();
      laporanListFiltered = laporanList.where((laporan) {
        final date = DateTime.parse(laporan['created_at']);
        return date.year == today.year &&
            date.month == today.month &&
            date.day == today.day;
      }).toList();
    } else if (selectedFilter == 'Minggu Ini') {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      laporanListFiltered = laporanList.where((laporan) {
        final date = DateTime.parse(laporan['created_at']);
        return date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
            date.isBefore(weekEnd.add(const Duration(days: 1)));
      }).toList();
    } else if (selectedFilter == 'Bulan Ini') {
      final now = DateTime.now();
      laporanListFiltered = laporanList.where((laporan) {
        final date = DateTime.parse(laporan['created_at']);
        return date.year == now.year && date.month == now.month;
      }).toList();
    } else if (selectedFilter == 'Custom' && customStartDate != null && customEndDate != null) {
      laporanListFiltered = laporanList.where((laporan) {
        final date = DateTime.parse(laporan['created_at']);
        return date.isAfter(customStartDate!.subtract(const Duration(days: 1))) &&
            date.isBefore(customEndDate!.add(const Duration(days: 1)));
      }).toList();
    } else {
      laporanListFiltered = List.from(laporanList);
    }
  }

  Future<void> _showFilterDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Filter Laporan',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilterOption('Semua'),
              _buildFilterOption('Hari Ini'),
              _buildFilterOption('Minggu Ini'),
              _buildFilterOption('Bulan Ini'),
              const Divider(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.date_range, color: Color(0xFF7C933F)),
                title: const Text('Pilih Tanggal Custom'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _showCustomDatePicker();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterOption(String filterName) {
    return RadioListTile<String>(
      contentPadding: EdgeInsets.zero,
      title: Text(filterName),
      value: filterName,
      groupValue: selectedFilter,
      activeColor: const Color(0xFF7C933F),
      onChanged: (value) {
        setState(() {
          selectedFilter = value!;
          customStartDate = null;
          customEndDate = null;
          _applyFilter();
        });
        Navigator.pop(context);
      },
    );
  }

  Future<void> _showCustomDatePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7C933F),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedFilter = 'Custom';
        customStartDate = picked.start;
        customEndDate = picked.end;
        _applyFilter();
      });
    }
  }

  String _getFilterText() {
    if (selectedFilter == 'Custom' && customStartDate != null && customEndDate != null) {
      return '${DateFormat('dd/MM/yy').format(customStartDate!)} - ${DateFormat('dd/MM/yy').format(customEndDate!)}';
    }
    return selectedFilter;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C933F), 
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white), 
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Riwayat Laporan',
          style: TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white), 
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chip
          if (selectedFilter != 'Semua')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EFE0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.filter_alt,
                            size: 16,
                            color: Color(0xFF7C933F),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _getFilterText(),
                              style: const TextStyle(
                                color: Color(0xFF7C933F),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedFilter = 'Semua';
                                customStartDate = null;
                                customEndDate = null;
                                _applyFilter();
                              });
                            },
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Color(0xFF7C933F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${laporanListFiltered.length} data',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          // List
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF7C933F),
                    ),
                  )
                : laporanListFiltered.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: fetchLaporan,
                        color: const Color(0xFF7C933F),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: laporanListFiltered.length,
                          itemBuilder: (context, index) {
                            return _buildLaporanCard(laporanListFiltered[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: Color(0xFFE8EFE0),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 50,
              color: Color(0xFF7C933F),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            selectedFilter == 'Semua' ? 'Belum Ada Laporan' : 'Tidak Ada Data',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            selectedFilter == 'Semua'
                ? 'Riwayat laporan akan muncul di sini'
                : 'Tidak ada laporan pada periode ini',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLaporanCard(Map laporan) {
    final tanggal = DateFormat('dd/MM/yyyy').format(
      DateTime.parse(
        laporan['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );

    final waktu = DateFormat('HH:mm').format(
      DateTime.parse(
        laporan['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailLaporPage(
                  judul: laporan['judul_laporan'],
                  uraian: laporan['uraian_kegiatan'],
                  status: laporan['status_validasi'],
                  tanggal: laporan['created_at']?.substring(0, 10) ?? '',
                  foto: laporan['foto_kegiatan'],
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        laporan['judul_laporan'] ?? 'Tanpa Judul',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildStatusBadge(laporan['status_validasi']),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 1,
                  color: const Color(0xFFE0E0E0),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Color(0xFF7C933F),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tanggal,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      waktu,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    laporan['uraian_kegiatan'] ?? '-',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailLaporPage(
                            judul: laporan['judul_laporan'],
                            uraian: laporan['uraian_kegiatan'],
                            status: laporan['status_validasi'],
                            tanggal: laporan['created_at']?.substring(0, 10) ?? '',
                            foto: laporan['foto_kegiatan'],
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C933F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Lihat Detail',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color bgColor;
    Color textColor;
    String text;

    switch (status?.toLowerCase()) {
      case 'approved':
        bgColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF059669);
        text = 'Disetujui';
        break;
      case 'rejected':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFDC2626);
        text = 'Ditolak';
        break;
      case 'pending':
      default:
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        text = 'Menunggu';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}