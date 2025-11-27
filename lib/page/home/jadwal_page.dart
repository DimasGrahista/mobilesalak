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
  String selectedFilter = 'Semua'; // Semua, Akan Datang, Berlangsung, Selesai
  String searchQuery = '';

  final List<String> filterOptions = [
    'Semua',
    'Akan Datang',
    'Berlangsung',
    'Selesai'
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

      debugPrint('[DEBUG] Response Status: ${response.statusCode}');
      debugPrint('[DEBUG] Response Body: ${response.body}');

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
    if (selectedFilter != 'Semua') {
      filtered = filtered.where((jadwal) {
        return jadwal.status == selectedFilter;
      }).toList();
    }

    // Filter berdasarkan search query
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((jadwal) {
        return jadwal.tugas.toLowerCase().contains(searchQuery.toLowerCase()) ||
            jadwal.blokLahan.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }

    // Sort berdasarkan tanggal jadwal (terbaru di atas)
    filtered.sort((a, b) {
      return DateTime.parse(b.tanggalJadwal)
          .compareTo(DateTime.parse(a.tanggalJadwal));
    });

    setState(() {
      filteredJadwalList = filtered;
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Akan Datang':
        return const Color(0xFF42A5F5); // Blue
      case 'Berlangsung':
        return const Color(0xFF66BB6A); // Green
      case 'Selesai':
        return const Color(0xFF9E9E9E); // Grey
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

  Future<void> _deleteJadwal(int idJadwal) async {
    final url = Uri.parse('${Config.apiUrl}/api/jadwal/$idJadwal');

    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jadwal berhasil dihapus'),
            backgroundColor: Colors.green,
          ),
        );
        await fetchJadwal();
      } else {
        throw Exception('Gagal menghapus jadwal');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showDeleteConfirmation(Jadwal jadwal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Konfirmasi Hapus'),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus jadwal "${jadwal.tugas}" di ${jadwal.blokLahan}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteJadwal(jadwal.idJadwal);
            },
            child: const Text(
              'Hapus',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
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
          // Search Bar
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                  _applyFilters();
                });
              },
              decoration: InputDecoration(
                hintText: 'Cari tugas atau blok lahan...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                border: InputBorder.none,
                icon: Icon(Icons.search, color: Colors.grey[400]),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          setState(() {
                            searchQuery = '';
                            _applyFilters();
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Filter Chips
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filterOptions.length,
              itemBuilder: (context, index) {
                final filter = filterOptions[index];
                final isSelected = selectedFilter == filter;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF636E72),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFF7C933F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF7C933F)
                            : Colors.grey[300]!,
                      ),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        selectedFilter = filter;
                        _applyFilters();
                      });
                    },
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Counter
          if (!isLoading && filteredJadwalList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${filteredJadwalList.length} Jadwal',
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
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.event_busy,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              searchQuery.isNotEmpty || selectedFilter != 'Semua'
                                  ? 'Tidak ada jadwal ditemukan'
                                  : 'Belum Ada Jadwal',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              searchQuery.isNotEmpty || selectedFilter != 'Semua'
                                  ? 'Coba ubah filter atau kata kunci'
                                  : 'Jadwal perawatan akan muncul di sini',
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
                        onRefresh: fetchJadwal,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredJadwalList.length,
                          itemBuilder: (context, index) {
                            final jadwal = filteredJadwalList[index];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
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
                                        builder: (context) =>
                                            DetailJadwalPage(jadwal: jadwal),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header: Tugas & Status
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    jadwal.tugas,
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
                                                        Icons.location_on,
                                                        size: 14,
                                                        color: Colors.grey[500],
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        jadwal.blokLahan,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.grey[600],
                                                          fontWeight:
                                                              FontWeight.w500,
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
                                                color: _getStatusColor(jadwal.status)
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    _getStatusIcon(jadwal.status),
                                                    size: 14,
                                                    color: _getStatusColor(
                                                        jadwal.status),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    jadwal.status,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: _getStatusColor(
                                                          jadwal.status),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 12),

                                        // Progress Bar (untuk status Berlangsung)
                                        if (jadwal.status == 'Berlangsung') ...[
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'Progress',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[600],
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${jadwal.progressPercentage.toStringAsFixed(0)}%',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF66BB6A),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: LinearProgressIndicator(
                                                  value: jadwal.progressPercentage /
                                                      100,
                                                  backgroundColor:
                                                      Colors.grey[200],
                                                  valueColor:
                                                      const AlwaysStoppedAnimation<
                                                          Color>(
                                                    Color(0xFF66BB6A),
                                                  ),
                                                  minHeight: 6,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                        ],

                                        // Info Periode & Durasi
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF5F7FA),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.calendar_today,
                                                      size: 16,
                                                      color: Colors.grey[600],
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            'Periode',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: Colors.grey[600],
                                                            ),
                                                          ),
                                                          Text(
                                                            '${jadwal.formatTanggal(jadwal.tanggalJadwal)} - ${jadwal.formatTanggal(jadwal.tanggalSelesai)}',
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight.w600,
                                                              color:
                                                                  Color(0xFF2D3436),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                width: 1,
                                                height: 30,
                                                color: Colors.grey[300],
                                                margin: const EdgeInsets.symmetric(
                                                    horizontal: 8),
                                              ),
                                              Column(
                                                children: [
                                                  Text(
                                                    '${jadwal.duration}',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF7C933F),
                                                    ),
                                                  ),
                                                  Text(
                                                    'Hari',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Sisa Hari (untuk yang Berlangsung)
                                        if (jadwal.status == 'Berlangsung' &&
                                            jadwal.sisaHari > 0) ...[
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 14,
                                                color: Colors.orange[700],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Sisa ${jadwal.sisaHari} hari lagi',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.orange[700],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],

                                        const SizedBox(height: 12),

                                        // Action Buttons
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            // Button Delete
                                            IconButton(
                                              onPressed: () =>
                                                  _showDeleteConfirmation(jadwal),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                size: 20,
                                              ),
                                              color: Colors.red,
                                              style: IconButton.styleFrom(
                                                backgroundColor:
                                                    Colors.red.withValues(alpha: 0.1),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Button Detail
                                            TextButton.icon(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        DetailJadwalPage(
                                                            jadwal: jadwal),
                                                  ),
                                                );
                                              },
                                              icon: const Icon(
                                                Icons.arrow_forward_ios,
                                                size: 12,
                                              ),
                                              label: const Text(
                                                'Detail',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    const Color(0xFF7C933F),
                                                padding:
                                                    const EdgeInsets.symmetric(
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigate ke halaman tambah jadwal
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(
          //     builder: (context) => TambahJadwalPage(),
          //   ),
          // ).then((_) => fetchJadwal()); // Refresh setelah tambah
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fitur tambah jadwal akan segera tersedia'),
              backgroundColor: Color(0xFF7C933F),
            ),
          );
        },
        backgroundColor: const Color(0xFF7C933F),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Buat Jadwal',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
