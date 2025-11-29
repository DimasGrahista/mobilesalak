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
  String selectedFilter = 'Akan Datang';
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

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeData() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');

    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token tidak ditemukan, silakan login ulang')),
      );
      if (mounted) {
        setState(() => isLoading = false);
      }
      return;
    }

    await fetchJadwal();
  }

  Future<void> fetchJadwal() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    if (token == null) {
      if (mounted) {
        setState(() => isLoading = false);
      }
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

      if (!mounted) return;

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
      if (mounted) {
        setState(() {
          jadwalList = [];
          filteredJadwalList = [];
          isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    List<Jadwal> filtered = jadwalList;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Filter berdasarkan status waktu
    if (selectedFilter == 'Akan Datang') {
      // Jadwal yang belum dimulai (tanggal mulai > hari ini)
      filtered = filtered.where((jadwal) {
        try {
          final mulai = DateTime.parse(jadwal.tanggalJadwal);
          final startDate = DateTime(mulai.year, mulai.month, mulai.day);
          return startDate.isAfter(today);
        } catch (e) {
          return false;
        }
      }).toList();
    } else if (selectedFilter == 'Selesai') {
      // Jadwal yang sudah selesai (tanggal selesai < hari ini)
      filtered = filtered.where((jadwal) {
        try {
          final selesai = DateTime.parse(jadwal.tanggalSelesai);
          final endDate = DateTime(selesai.year, selesai.month, selesai.day);
          return endDate.isBefore(today);
        } catch (e) {
          return false;
        }
      }).toList();
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

    if (mounted) {
      setState(() {
        filteredJadwalList = filtered;
      });
    }
  }

  List<Jadwal> _getTodaySchedules() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final filtered = jadwalList.where((jadwal) {
      try {
        // Parse tanggal jadwal dan tanggal selesai
        final mulai = DateTime.parse(jadwal.tanggalJadwal);
        final startDate = DateTime(mulai.year, mulai.month, mulai.day);
        
        final selesai = DateTime.parse(jadwal.tanggalSelesai);
        final endDate = DateTime(selesai.year, selesai.month, selesai.day);

        // Jadwal yang aktif hari ini (hari ini ada di antara tanggal mulai dan selesai)
        return (today.isAtSameMomentAs(startDate) || 
                today.isAtSameMomentAs(endDate) ||
                (today.isAfter(startDate) && today.isBefore(endDate)));
      } catch (e) {
        return false;
      }
    }).toList();

    // Sort berdasarkan tanggal mulai (yang paling awal di atas)
    filtered.sort((a, b) {
      return DateTime.parse(a.tanggalJadwal)
          .compareTo(DateTime.parse(b.tanggalJadwal));
    });

    return filtered;
  }

  Color _getStatusColor(String status) {
    // Karena tidak ada status, gunakan warna default hijau
    return const Color(0xFF7C933F);
  }

  // Minimalist Today Schedule Card - Show only latest one
  Widget _buildTodayScheduleCard() {
    final todaySchedules = _getTodaySchedules();
    final now = DateTime.now();
    
    // Ambil hanya jadwal terbaru (yang pertama setelah di-sort)
    final latestSchedule = todaySchedules.isNotEmpty ? todaySchedules.first : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF7C933F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hari Ini',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_getTodayName()}, ${now.day}/${now.month}/${now.year}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              if (todaySchedules.length > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+${todaySchedules.length - 1} lagi',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          if (latestSchedule != null) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white30, height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latestSchedule.tugas,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        latestSchedule.blokLahan,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailJadwalPage(jadwal: latestSchedule),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.white,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3436)),
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
      ),
      body: Column(
        children: [
          // Today Schedule Card
          if (!isLoading) _buildTodayScheduleCard(),

          // Filter Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: filterOptions.map((option) {
                final isSelected = selectedFilter == option;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (mounted) {
                        setState(() {
                          selectedFilter = option;
                          _applyFilters();
                        });
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF7C933F) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        option,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[600],
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

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
                              Icons.event_note_outlined,
                              size: 64,
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
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: fetchJadwal,
                        color: const Color(0xFF7C933F),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: filteredJadwalList.length,
                          itemBuilder: (context, index) {
                            final jadwal = filteredJadwalList[index];
                            return _buildMinimalistJadwalCard(jadwal);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalistJadwalCard(Jadwal jadwal) {
    final statusColor = _getStatusColor('');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Cek apakah jadwal sudah selesai
    final selesai = DateTime.parse(jadwal.tanggalSelesai);
    final endDate = DateTime(selesai.year, selesai.month, selesai.day);
    final isSelesai = endDate.isBefore(today);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
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
            child: Row(
              children: [
                // Left color indicator
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isSelesai ? Colors.grey[400] : statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        jadwal.tugas,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isSelesai ? Colors.grey[500] : const Color(0xFF2D3436),
                          decoration: isSelesai ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      
                      // Location
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              jadwal.blokLahan,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      
                      // Date range
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${jadwal.formatTanggal(jadwal.tanggalJadwal)} - ${jadwal.formatTanggal(jadwal.tanggalSelesai)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Right side - Days remaining
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (isSelesai ? Colors.grey[400] : statusColor)!.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        jadwal.sisaHari > 0 ? '${jadwal.sisaHari}h' : 'Akhir',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelesai ? Colors.grey[600] : statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey[400],
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