import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kebunsalak_app/config/config.dart';
import 'package:intl/intl.dart';

class Penggajian {
  final int idGaji;
  final int idKaryawan;
  final String bulan;
  final int tahun;
  final double gajiPokok;
  final double tunjangan;
  final double potongan;
  final double bonus;
  final double totalGaji;
  final String statusPenggajian;
  final String? tanggalBayar;
  final String? namaKaryawan;

  Penggajian({
    required this.idGaji,
    required this.idKaryawan,
    required this.bulan,
    required this.tahun,
    required this.gajiPokok,
    required this.tunjangan,
    required this.potongan,
    required this.bonus,
    required this.totalGaji,
    required this.statusPenggajian,
    this.tanggalBayar,
    this.namaKaryawan,
  });

  factory Penggajian.fromJson(Map<String, dynamic> json) {
    return Penggajian(
      idGaji: json['id_gaji'] ?? 0,
      idKaryawan: json['id_karyawan'] ?? 0,
      bulan: json['bulan'] ?? '',
      tahun: json['tahun'] ?? 0,
      gajiPokok: double.tryParse(json['gaji_pokok']?.toString() ?? '0') ?? 0,
      tunjangan: double.tryParse(json['tunjangan']?.toString() ?? '0') ?? 0,
      potongan: double.tryParse(json['potongan']?.toString() ?? '0') ?? 0,
      bonus: double.tryParse(json['bonus']?.toString() ?? '0') ?? 0,
      totalGaji: double.tryParse(json['total_gaji']?.toString() ?? '0') ?? 0,
      statusPenggajian: json['status_penggajian'] ?? 'Unpaid',
      tanggalBayar: json['tanggal_bayar'],
      namaKaryawan: json['karyawan']?['nama_kar'],
    );
  }
}

class PenggajianPage extends StatefulWidget {
  const PenggajianPage({super.key});

  @override
  State<PenggajianPage> createState() => _PenggajianPageState();
}

class _PenggajianPageState extends State<PenggajianPage> {
  List<Penggajian> penggajianList = [];
  List<Penggajian> filteredPenggajianList = [];
  bool isLoading = true;
  String? token;
  int? currentKaryawanId;
  String selectedFilter = 'Semua';
  String searchQuery = '';

  final List<String> filterOptions = [
    'Semua',
    'Sudah Dibayar',
    'Belum Dibayar',
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    
    // Baca sebagai String lalu konversi ke int
    String? idKaryawanStr = prefs.getString('id_karyawan');
    currentKaryawanId = idKaryawanStr != null ? int.tryParse(idKaryawanStr) : null;

    if (token == null || currentKaryawanId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data karyawan tidak ditemukan, silakan login ulang')),
      );
      setState(() => isLoading = false);
      return;
    }

    await fetchPenggajian();
  }

  Future<void> fetchPenggajian() async {
    setState(() => isLoading = true);

    if (token == null || currentKaryawanId == null) {
      setState(() => isLoading = false);
      return;
    }

    final url = Uri.parse('${Config.apiUrl}/api/penggajian');

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

        List<Penggajian> tempList = [];

        // Handle berbagai struktur response
        if (data is List) {
          tempList = List<Penggajian>.from(
            data.map((item) => Penggajian.fromJson(item)),
          );
        } else if (data is Map) {
          // Laravel pagination: data.data.data
          if (data['data'] != null) {
            if (data['data'] is List) {
              tempList = List<Penggajian>.from(
                data['data'].map((item) => Penggajian.fromJson(item)),
              );
            } else if (data['data']['data'] is List) {
              tempList = List<Penggajian>.from(
                data['data']['data'].map((item) => Penggajian.fromJson(item)),
              );
            }
          }
        }

        // ========== FILTER BERDASARKAN ID KARYAWAN LOGIN ==========
        tempList = tempList.where((gaji) {
          return gaji.idKaryawan == currentKaryawanId;
        }).toList();

        debugPrint('✅ Filtered Penggajian for karyawan ID $currentKaryawanId: ${tempList.length} items');

        setState(() {
          penggajianList = tempList;
          _applyFilters();
          isLoading = false;
        });
      } else {
        setState(() {
          penggajianList = [];
          filteredPenggajianList = [];
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[ERROR] fetchPenggajian exception: $e');
      setState(() {
        penggajianList = [];
        filteredPenggajianList = [];
        isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<Penggajian> filtered = penggajianList;

    // Filter berdasarkan status
    if (selectedFilter == 'Sudah Dibayar') {
      filtered = filtered.where((p) => p.statusPenggajian == 'Paid').toList();
    } else if (selectedFilter == 'Belum Dibayar') {
      filtered = filtered.where((p) => p.statusPenggajian == 'Unpaid').toList();
    }

    // Filter berdasarkan search query
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((p) {
        return p.bulan.toLowerCase().contains(searchQuery.toLowerCase()) ||
            p.tahun.toString().contains(searchQuery) ||
            (p.namaKaryawan?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false);
      }).toList();
    }

    // Sort berdasarkan tahun dan bulan terbaru
    filtered.sort((a, b) {
      final yearCompare = b.tahun.compareTo(a.tahun);
      if (yearCompare != 0) return yearCompare;
      
      // Sort bulan
      final months = {
        'januari': 1, 'februari': 2, 'maret': 3, 'april': 4,
        'mei': 5, 'juni': 6, 'juli': 7, 'agustus': 8,
        'september': 9, 'oktober': 10, 'november': 11, 'desember': 12
      };
      final aMonth = months[a.bulan.toLowerCase()] ?? 0;
      final bMonth = months[b.bulan.toLowerCase()] ?? 0;
      return bMonth.compareTo(aMonth);
    });

    setState(() {
      filteredPenggajianList = filtered;
    });
  }

  Color _getStatusColor(String status) {
    return status == 'Paid' 
        ? const Color(0xFF66BB6A) 
        : const Color(0xFFF59E0B);
  }

  IconData _getStatusIcon(String status) {
    return status == 'Paid' 
        ? Icons.check_circle 
        : Icons.pending;
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  Widget _buildSummaryCard() {
    final totalPaid = penggajianList
        .where((p) => p.statusPenggajian == 'Paid')
        .fold<double>(0, (sum, p) => sum + p.totalGaji);
    
    final totalUnpaid = penggajianList
        .where((p) => p.statusPenggajian == 'Unpaid')
        .fold<double>(0, (sum, p) => sum + p.totalGaji);

    final countPaid = penggajianList.where((p) => p.statusPenggajian == 'Paid').length;
    final countUnpaid = penggajianList.where((p) => p.statusPenggajian == 'Unpaid').length;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7C933F),
            const Color(0xFF7C933F).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C933F).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ringkasan Gaji Saya',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Data penggajian pribadi',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Sudah Dibayar',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatCurrency(totalPaid),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$countPaid gaji',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.pending,
                              size: 16,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Belum Dibayar',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatCurrency(totalUnpaid),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$countUnpaid gaji',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
          'Gaji Saya',
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
          // Summary Card
          if (!isLoading) _buildSummaryCard(),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                  _applyFilters();
                });
              },
              decoration: InputDecoration(
                hintText: 'Cari bulan, tahun, atau nama...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Filter Chips
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filterOptions.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final option = filterOptions[index];
                final isSelected = selectedFilter == option;

                return FilterChip(
                  label: Text(
                    option,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF7C933F),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      selectedFilter = option;
                      _applyFilters();
                    });
                  },
                  backgroundColor: Colors.white,
                  selectedColor: const Color(0xFF7C933F),
                  checkmarkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF7C933F)
                          : Colors.grey[300]!,
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // List Penggajian
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF7C933F),
                    ),
                  )
                : filteredPenggajianList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ada data gaji',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Belum ada riwayat gaji Anda',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: fetchPenggajian,
                        color: const Color(0xFF7C933F),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredPenggajianList.length,
                          itemBuilder: (context, index) {
                            final gaji = filteredPenggajianList[index];
                            return _buildPenggajianCard(gaji);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPenggajianCard(Penggajian gaji) {
    final statusColor = _getStatusColor(gaji.statusPenggajian);
    final statusIcon = _getStatusIcon(gaji.statusPenggajian);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDetailDialog(gaji),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header dengan status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            statusIcon,
                            size: 14,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            gaji.statusPenggajian == 'Paid' ? 'Dibayar' : 'Pending',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${gaji.bulan} ${gaji.tahun}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Nama Karyawan
                Text(
                  gaji.namaKaryawan ?? 'Karyawan #${gaji.idKaryawan}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3436),
                  ),
                ),

                const SizedBox(height: 12),

                // Detail Gaji
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C933F).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Gaji Pokok', gaji.gajiPokok),
                      if (gaji.tunjangan > 0) ...[
                        const SizedBox(height: 6),
                        _buildDetailRow('Tunjangan', gaji.tunjangan, isPositive: true),
                      ],
                      if (gaji.bonus > 0) ...[
                        const SizedBox(height: 6),
                        _buildDetailRow('Bonus', gaji.bonus, isPositive: true),
                      ],
                      if (gaji.potongan > 0) ...[
                        const SizedBox(height: 6),
                        _buildDetailRow('Potongan', gaji.potongan, isNegative: true),
                      ],
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Gaji',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3436),
                            ),
                          ),
                          Text(
                            _formatCurrency(gaji.totalGaji),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7C933F),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tanggal Bayar
                if (gaji.tanggalBayar != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Dibayar: ${_formatDate(gaji.tanggalBayar!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, double amount, {bool isPositive = false, bool isNegative = false}) {
    Color color = Colors.grey[700]!;
    String prefix = '';
    
    if (isPositive) {
      color = const Color(0xFF66BB6A);
      prefix = '+';
    } else if (isNegative) {
      color = const Color(0xFFEF5350);
      prefix = '-';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        Text(
          '$prefix${_formatCurrency(amount)}',
          style: TextStyle(
            fontSize: 13,
            color: color,
            fontWeight: isPositive || isNegative ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  String _formatDate(String date) {
    try {
      final dateTime = DateTime.parse(date);
      return DateFormat('dd MMM yyyy', 'id_ID').format(dateTime);
    } catch (e) {
      return date;
    }
  }

  void _showDetailDialog(Penggajian gaji) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Detail Penggajian'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Nama Karyawan', gaji.namaKaryawan ?? '-'),
              _buildInfoRow('ID Karyawan', gaji.idKaryawan.toString()),
              _buildInfoRow('Periode', '${gaji.bulan} ${gaji.tahun}'),
              const Divider(height: 20),
              _buildInfoRow('Gaji Pokok', _formatCurrency(gaji.gajiPokok)),
              _buildInfoRow('Tunjangan', _formatCurrency(gaji.tunjangan)),
              _buildInfoRow('Bonus', _formatCurrency(gaji.bonus)),
              _buildInfoRow('Potongan', _formatCurrency(gaji.potongan)),
              const Divider(height: 20),
              _buildInfoRow('Total Gaji', _formatCurrency(gaji.totalGaji), isBold: true),
              _buildInfoRow('Status', gaji.statusPenggajian == 'Paid' ? 'Sudah Dibayar' : 'Belum Dibayar'),
              if (gaji.tanggalBayar != null)
                _buildInfoRow('Tanggal Bayar', _formatDate(gaji.tanggalBayar!)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? const Color(0xFF7C933F) : const Color(0xFF2D3436),
            ),
          ),
        ],
      ),
    );
  }
}