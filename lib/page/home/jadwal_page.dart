import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kebunsalak_app/config/config.dart';
import 'package:kebunsalak_app/models/jadwal.dart';
import 'detail_jadwal_page.dart';

class JadwalKegiatanPage extends StatefulWidget {
  const JadwalKegiatanPage({super.key});

  @override
  State<JadwalKegiatanPage> createState() => _JadwalKegiatanPageState();
}

class _JadwalKegiatanPageState extends State<JadwalKegiatanPage> {
  List<Jadwal> jadwalList = [];
  List<Jadwal> filteredJadwalList = [];
  bool isLoading = true;
  String? token;
  String selectedFilter = 'Akan Datang'; // Default ke Akan Datang
  String searchQuery = '';

  final List<String> filterOptions = [
    'Akan Datang',
    'Selesai',
    'Semua',
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');

    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token tidak ditemukan, silakan login ulang')),
      );
      setState(() => isLoading = false);
      return;
    }

    await fetchJadwal();
  }

  Future<void> fetchJadwal() async {
    setState(() => isLoading = true);

    if (token == null) {
      setState(() => isLoading = false);
      return;
    }

    final url = Uri.parse('${Config.apiUrl}/api/jadwals');

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
            jadwalList = List<Jadwal>.from(
              data.map((item) => Jadwal.fromJson(item)),
            );
            _applyFilters();
            isLoading = false;
          });
        }
      } else {
        setState(() {
          jadwalList = [];
          filteredJadwalList = [];
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[ERROR] fetchJadwal exception: $e');
      setState(() {
        jadwalList = [];
        filteredJadwalList = [];
        isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<Jadwal> filtered = jadwalList;

    // Filter berdasarkan status
    if (selectedFilter == 'Akan Datang') {
      filtered = filtered.where((jadwal) => jadwal.status == 'Akan Datang').toList();
    } else if (selectedFilter == 'Selesai') {
      filtered = filtered.where((jadwal) => jadwal.status == 'Selesai').toList();
    }
    // Untuk 'Semua', tidak perlu filter

    // Filter berdasarkan search query
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((jadwal) {
        return jadwal.tugas.toLowerCase().contains(searchQuery.toLowerCase()) ||
            jadwal.blokLahan.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }

    // Sort berdasarkan tanggal
    filtered.sort((a, b) {
      return DateTime.parse(a.tanggalJadwal)
          .compareTo(DateTime.parse(b.tanggalJadwal));
    });

    setState(() {
      filteredJadwalList = filtered;
    });
  }

  // Method untuk mendapatkan jadwal hari ini
  List<Jadwal> _getTodaySchedules() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return jadwalList.where((jadwal) {
      try {
        final mulai = DateTime.parse(jadwal.tanggalJadwal);
        final startDate = DateTime(mulai.year, mulai.month, mulai.day);

        final selesai = DateTime.parse(jadwal.tanggalSelesai);
        final endDate = DateTime(selesai.year, selesai.month, selesai.day);

        // Jadwal aktif hari ini
        return (today.isAtSameMomentAs(startDate) ||
                today.isAtSameMomentAs(endDate) ||
                (today.isAfter(startDate) && today.isBefore(endDate))) &&
               !today.isAfter(endDate);
      } catch (e) {
        return false;
      }
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Akan Datang':
        return const Color(0xFF42A5F5);
      case 'Berlangsung':
        return const Color(0xFF66BB6A);
      case 'Selesai':
        return const Color(0xFF9E9E9E);
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Akan Datang':
        return Icons.schedule;
      case 'Berlangsung':
        return Icons.autorenew;
      case 'Selesai':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }
  // Widget untuk card jadwal hari ini
  Widget _buildTodayScheduleCard() {
    final todaySchedules = _getTodaySchedules();
    final now = DateTime.now();

    return Container(
      width: double.infinity,
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
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.today,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Jadwal Hari Ini',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_getTodayName()}, ${now.day}/${now.month}/${now.year}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${todaySchedules.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Content
            if (todaySchedules.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_available,
                      size: 40,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tidak Ada Jadwal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tidak ada perawatan yang dijadwalkan untuk hari ini',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else ...[
              ...todaySchedules.asMap().entries.map((entry) {
                final index = entry.key;
                final jadwal = entry.value;

                return Container(
                  margin: EdgeInsets.only(bottom: index < todaySchedules.length - 1 ? 12 : 0),
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  jadwal.tugas,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      jadwal.blokLahan,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.autorenew,
                                  size: 12,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'AKTIF',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${jadwal.formatTanggal(jadwal.tanggalJadwal)} - ${jadwal.formatTanggal(jadwal.tanggalSelesai)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 12,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  jadwal.sisaHari > 0 
                                      ? '${jadwal.sisaHari} hari'
                                      : 'Terakhir',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DetailJadwalPage(jadwal: jadwal),
                                ),
                              );
                            },
                            icon: Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            label: Text(
                              'Lihat Detail',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
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
          'Jadwal Perawatan',
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
          // Card Jadwal Hari Ini
          if (!isLoading) _buildTodayScheduleCard(),

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

          // List Jadwal
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF7C933F),
                    ),
                  )
                : filteredJadwalList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ada jadwal',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Belum ada jadwal untuk kategori ini',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: fetchJadwal,
                        color: const Color(0xFF7C933F),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredJadwalList.length,
                          itemBuilder: (context, index) {
                            final jadwal = filteredJadwalList[index];
                            return _buildJadwalCard(jadwal);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildJadwalCard(Jadwal jadwal) {
    final statusColor = _getStatusColor(jadwal.status);
    final statusIcon = _getStatusIcon(jadwal.status);

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
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailJadwalPage(jadwal: jadwal),
              ),
            );
            if (result == true && mounted) {
              fetchJadwal();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header dengan status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badge
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
                            jadwal.status,
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
                    // Menu button
                    // PopupMenuButton<String>(
                    //   icon: Icon(
                    //     Icons.more_vert,
                    //     color: Colors.grey[600],
                    //     size: 20,
                    //   ),
                    //   shape: RoundedRectangleBorder(
                    //     borderRadius: BorderRadius.circular(12),
                    //   ),
                    //   onSelected: (value) async {
                    //     if (value == 'edit') {
                    //       final result = await Navigator.pushNamed(
                    //         context,
                    //         '/edit-jadwal',
                    //         arguments: jadwal,
                    //       );
                    //       if (result == true && mounted) {
                    //         fetchJadwal();
                    //       }
                    //     } else if (value == 'delete') {
                    //       _showDeleteConfirmation(jadwal);
                    //     }
                    //   },
                    //   itemBuilder: (context) => [
                    //     const PopupMenuItem(
                    //       value: 'edit',
                    //       child: Row(
                    //         children: [
                    //           Icon(Icons.edit, size: 18, color: Color(0xFF7C933F)),
                    //           SizedBox(width: 12),
                    //           Text('Edit'),
                    //         ],
                    //       ),
                    //     ),
                    //     const PopupMenuItem(
                    //       value: 'delete',
                    //       child: Row(
                    //         children: [
                    //           Icon(Icons.delete, size: 18, color: Colors.red),
                    //           SizedBox(width: 12),
                    //           Text('Hapus'),
                    //         ],
                    //       ),
                    //     ),
                    //   ],
                    // ),
                  ],
                ),

                const SizedBox(height: 12),

                // Judul Tugas
                Text(
                  jadwal.tugas,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3436),
                  ),
                ),

                const SizedBox(height: 8),

                // Blok Lahan
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        jadwal.blokLahan,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Footer Info
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${jadwal.formatTanggal(jadwal.tanggalJadwal)} - ${jadwal.formatTanggal(jadwal.tanggalSelesai)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C933F).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 12,
                            color: Color(0xFF7C933F),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            jadwal.sisaHari > 0 ? '${jadwal.sisaHari} hari' : 'Terakhir',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF7C933F),
                            ),
                          ),
                        ],
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
  }

  String _getTodayName() {
    final now = DateTime.now();
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    return days[now.weekday % 7];
  }
}