  import 'dart:convert';
  import 'package:flutter/material.dart';
  import 'package:http/http.dart' as http;
  import 'package:shared_preferences/shared_preferences.dart';
  import 'package:kebunsalak_app/config/config.dart';
  import 'package:intl/intl.dart';

  class RiwayatAbsensiPage extends StatefulWidget {
    const RiwayatAbsensiPage({super.key});

    @override
    State<RiwayatAbsensiPage> createState() => _RiwayatAbsensiPageState();
  }

  class _RiwayatAbsensiPageState extends State<RiwayatAbsensiPage> {
    List<Map<String, dynamic>> riwayatList = [];
    List<Map<String, dynamic>> filteredList = [];
    List<String> availableMonths = [];
    bool isLoading = true;
    String? selectedMonth;

    @override
    void initState() {
      super.initState();
      fetchRiwayatAbsensi();
    }

    // Fetch data absensi dan cuti
    Future<void> fetchRiwayatAbsensi() async {
      print('═══════════════════════════════════════════════════');
      print('🔄 MULAI FETCH DATA RIWAYAT ABSENSI');
      print('═══════════════════════════════════════════════════');
      
      setState(() {
        isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final idKaryawan = prefs.getString('id_karyawan');

      print('📌 Token: ${token != null ? "✅ Ada (${token.substring(0, 20)}...)" : "❌ Tidak ada"}');
      print('📌 ID Karyawan: ${idKaryawan ?? "❌ Tidak ada"}');

      if (token == null || idKaryawan == null) {
        setState(() => isLoading = false);
        print('❌ ERROR: Token atau ID Karyawan tidak ditemukan!');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token atau ID Karyawan tidak ditemukan, silakan login ulang')),
        );
        return;
      }

      try {
        // URL endpoints - TAMBAHKAN id_karyawan sebagai query parameter
        final absensiUrl = '${Config.apiUrl}/api/absensi/history?id_karyawan=$idKaryawan';
        final cutiUrl = '${Config.apiUrl}/api/cuti/$idKaryawan';
        
        print('\n📡 ENDPOINT ABSENSI: $absensiUrl');
        print('📡 ENDPOINT CUTI: $cutiUrl');
        print('\n⏳ Mengirim request...\n');

        // Fetch absensi dan cuti secara paralel
        final responses = await Future.wait([
          http.get(
            Uri.parse(absensiUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          ),
          http.get(
            Uri.parse(cutiUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          ),
        ]);

        print('─────────────────────────────────────────────────');
        print('📥 RESPONSE ABSENSI');
        print('─────────────────────────────────────────────────');
        print('Status Code: ${responses[0].statusCode}');
        print('Response Body: ${responses[0].body}');
        print('─────────────────────────────────────────────────\n');

        print('─────────────────────────────────────────────────');
        print('📥 RESPONSE CUTI');
        print('─────────────────────────────────────────────────');
        print('Status Code: ${responses[1].statusCode}');
        print('Response Body: ${responses[1].body}');
        print('─────────────────────────────────────────────────\n');

        if (responses[0].statusCode == 200) {
          print('✅ Response Absensi berhasil (200)');
          
          try {
            final absensiData = jsonDecode(responses[0].body);
            print('📦 Parsing JSON Absensi: SUCCESS');
            print('📊 Tipe data: ${absensiData.runtimeType}');
            
            List<Map<String, dynamic>> tempList = [];
            
            // Process absensi data
            if (absensiData['data'] != null) {
              print('✅ Data absensi ditemukan');
              print('📊 Jumlah record absensi: ${absensiData['data'].length}');
              
              Map<String, Map<String, dynamic>> groupedData = {};
              
              int processedCount = 0;
              for (var item in absensiData['data']) {
                print('\n📝 Processing absensi #${++processedCount}');
                print('   Data: $item');
                
                String tanggal = item['tanggal'] ?? '';
                print('   Tanggal: $tanggal');
                
                if (tanggal.isNotEmpty) {
                  try {
                    DateTime date = DateTime.parse(tanggal);
                    String dateKey = DateFormat('yyyy-MM-dd').format(date);
                    print('   Date Key: $dateKey');
                    
                    if (!groupedData.containsKey(dateKey)) {
                      groupedData[dateKey] = {
                        'tanggal': date,
                        'status': 'Hadir',
                        'jamMasuk': '',
                        'jamKeluar': '',
                      };
                      print('   ✅ Created new entry for $dateKey');
                    }
                    
                    // Update jam masuk atau keluar
                    if (item['status'] == 'in') {
                      groupedData[dateKey]!['jamMasuk'] = item['waktu'] ?? '-';
                      print('   ⏰ Jam Masuk: ${item['waktu']}');
                    } else if (item['status'] == 'out') {
                      groupedData[dateKey]!['jamKeluar'] = item['waktu'] ?? '-';
                      print('   ⏰ Jam Keluar: ${item['waktu']}');
                    }
                  } catch (e) {
                    print('   ❌ ERROR parsing tanggal: $e');
                  }
                } else {
                  print('   ⚠️ WARNING: Tanggal kosong, skip');
                }
              }
              
              print('\n📊 Total grouped absensi: ${groupedData.length}');
              tempList.addAll(groupedData.values);
              print('✅ Absensi data added to tempList: ${tempList.length} items');
            } else {
              print('⚠️ WARNING: absensiData["data"] is NULL');
            }

            // Process cuti data (jika ada)
            if (responses[1].statusCode == 200) {
              print('\n✅ Response Cuti berhasil (200)');
              
              try {
                final cutiData = jsonDecode(responses[1].body);
                print('📦 Parsing JSON Cuti: SUCCESS');
                print('📊 Tipe data: ${cutiData.runtimeType}');
                
                if (cutiData is List) {
                  print('📊 Jumlah record cuti: ${cutiData.length}');
                  
                  int cutiCount = 0;
                  int approvedCount = 0;
                  for (var item in cutiData) {
                    cutiCount++;
                    print('\n📝 Processing cuti #$cutiCount');
                    print('   Kategori: ${item['kategori']}');
                    print('   Status Validasi: ${item['status_validasi']}');
                    
                    if (item['status_validasi'] == 'Approved') {
                      approvedCount++;
                      String tanggalMulai = item['tanggal_mulai'] ?? '';
                      String tanggalAkhir = item['tanggal_akhir'] ?? '';
                      
                      print('   📅 Tanggal Mulai: $tanggalMulai');
                      print('   📅 Tanggal Akhir: $tanggalAkhir');
                      
                      if (tanggalMulai.isNotEmpty && tanggalAkhir.isNotEmpty) {
                        try {
                          DateTime startDate = DateTime.parse(tanggalMulai);
                          DateTime endDate = DateTime.parse(tanggalAkhir);
                          
                          print('   🔄 Loop dari $startDate sampai $endDate');
                          
                          int dayCount = 0;
                          // Loop untuk setiap hari cuti
                          for (DateTime date = startDate;
                              date.isBefore(endDate.add(const Duration(days: 1)));
                              date = date.add(const Duration(days: 1))) {
                            
                            dayCount++;
                            print('      Hari ke-$dayCount: ${DateFormat('yyyy-MM-dd').format(date)}');
                            
                            // Cek apakah tanggal ini sudah ada di absensi
                            bool sudahAda = tempList.any((element) {
                              DateTime existingDate = element['tanggal'];
                              return existingDate.year == date.year &&
                                  existingDate.month == date.month &&
                                  existingDate.day == date.day;
                            });
                            
                            if (!sudahAda) {
                              tempList.add({
                                'tanggal': date,
                                'status': 'Cuti',
                                'jamMasuk': '-',
                                'jamKeluar': '-',
                                'kategoriCuti': item['kategori'] ?? 'Cuti',
                              });
                              print('      ✅ Added cuti data');
                            } else {
                              print('      ⚠️ Already exists in absensi, skip');
                            }
                          }
                          print('   ✅ Total hari cuti ditambahkan: $dayCount');
                        } catch (e) {
                          print('   ❌ ERROR parsing tanggal cuti: $e');
                        }
                      } else {
                        print('   ⚠️ WARNING: Tanggal mulai/akhir kosong');
                      }
                    } else {
                      print('   ⏭️ SKIP: Status = ${item['status_validasi']} (bukan Approved)');
                    }
                  }
                  print('\n📊 Summary Cuti:');
                  print('   Total cuti records: $cutiCount');
                  print('   Approved cuti: $approvedCount');
                  print('   Rejected/Pending: ${cutiCount - approvedCount}');
                } else {
                  print('⚠️ WARNING: cutiData bukan List, tipe: ${cutiData.runtimeType}');
                }
              } catch (e) {
                print('❌ ERROR parsing JSON Cuti: $e');
              }
            } else if (responses[1].statusCode == 404) {
              print('⚠️ Cuti data not found (404) - No problem, continue');
            } else {
              print('⚠️ WARNING: Cuti response status ${responses[1].statusCode}');
            }

            print('\n📊 TOTAL DATA SEBELUM SORTING: ${tempList.length}');
            
            if (tempList.isEmpty) {
              print('⚠️⚠️⚠️ WARNING: tempList KOSONG! ⚠️⚠️⚠️');
              print('Kemungkinan penyebab:');
              print('1. Tidak ada data absensi di database');
              print('2. Tidak ada cuti yang berstatus Approved');
              print('3. Format data dari API tidak sesuai');
            }
            
            // Sort berdasarkan tanggal terbaru
            tempList.sort((a, b) => b['tanggal'].compareTo(a['tanggal']));
            print('✅ Data sorted by tanggal (terbaru dulu)');

            // Extract available months
            print('\n🗓️ Extracting available months...');
            Set<String> monthsSet = {};
            for (var item in tempList) {
              DateTime date = item['tanggal'];
              String monthYear = DateFormat('MMMM yyyy', 'id_ID').format(date);
              monthsSet.add(monthYear);
            }
            
            availableMonths = monthsSet.toList();
            if (availableMonths.isNotEmpty) {
              availableMonths.insert(0, 'Semua'); // Tambahkan opsi "Semua"
            }
            
            print('📅 Available months: $availableMonths');
            
            setState(() {
              riwayatList = tempList;
              selectedMonth = availableMonths.isNotEmpty ? availableMonths[0] : null;
              filteredList = filterByMonth(selectedMonth ?? 'Semua');
              isLoading = false;
            });
            
            print('\n═══════════════════════════════════════════════════');
            print('✅ FETCH DATA SELESAI');
            print('═══════════════════════════════════════════════════');
            print('📊 Total riwayatList: ${riwayatList.length}');
            print('📊 Total filteredList: ${filteredList.length}');
            print('📅 Selected Month: $selectedMonth');
            print('═══════════════════════════════════════════════════\n');
            
            // Tampilkan pesan jika data kosong
            if (tempList.isEmpty && !mounted) return;
            if (tempList.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tidak ada data kehadiran atau cuti yang approved'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
            
          } catch (e, stackTrace) {
            print('❌ FATAL ERROR saat parsing data: $e');
            print('Stack trace: $stackTrace');
            setState(() => isLoading = false);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error parsing data: $e')),
            );
          }
        } else {
          print('❌ ERROR: Absensi response status ${responses[0].statusCode}');
          print('❌ ERROR MESSAGE: ${responses[0].body}');
          setState(() => isLoading = false);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memuat data absensi: ${responses[0].body}')),
          );
        }
      } catch (e, stackTrace) {
        print('\n❌❌❌ FATAL ERROR ❌❌❌');
        print('Error: $e');
        print('Stack trace: $stackTrace');
        print('═══════════════════════════════════════════════════\n');
        
        setState(() => isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e')),
        );
      }
    }

    // Filter berdasarkan bulan
    List<Map<String, dynamic>> filterByMonth(String month) {
      print('\n🔍 FILTER BY MONTH: $month');
      
      if (month == 'Semua') {
        print('✅ Menampilkan semua data: ${riwayatList.length} items');
        return riwayatList;
      }
      
      var filtered = riwayatList.where((item) {
        DateTime date = item['tanggal'];
        String monthYear = DateFormat('MMMM yyyy', 'id_ID').format(date);
        return monthYear == month;
      }).toList();
      
      print('✅ Data terfilter untuk $month: ${filtered.length} items');
      return filtered;
    }

    @override
    Widget build(BuildContext context) {
      print('\n🎨 BUILD WIDGET - isLoading: $isLoading, filteredList: ${filteredList.length}');
      
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: const Color(0xFF7C933F),
          elevation: 0,
          leading: const BackButton(color: Colors.white),
          title: const Text(
            'Riwayat Kehadiran',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            // Filter Bulan
            if (availableMonths.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month,
                      color: Color(0xFF7C933F),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Periode:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
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
                            icon: const Icon(Icons.arrow_drop_down, size: 24),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                            items: availableMonths.map((String month) {
                              return DropdownMenuItem<String>(
                                value: month,
                                child: Text(month),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                print('📅 User selected month: $newValue');
                                setState(() {
                                  selectedMonth = newValue;
                                  filteredList = filterByMonth(newValue);
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // // Debug Info (Hapus ini di production)
            // Container(
            //   width: double.infinity,
            //   padding: const EdgeInsets.all(8),
            //   color: Colors.yellow[50],
            //   child: Column(
            //     crossAxisAlignment: CrossAxisAlignment.start,
            //     children: [
            //       Text(
            //         '🐛 DEBUG INFO:',
            //         style: TextStyle(
            //           fontSize: 11,
            //           fontWeight: FontWeight.bold,
            //           color: Colors.orange[900],
            //         ),
            //       ),
            //       Text(
            //         'Loading: $isLoading | Total Data: ${riwayatList.length} | Filtered: ${filteredList.length}',
            //         style: TextStyle(fontSize: 10, color: Colors.orange[900]),
            //       ),
            //       Text(
            //         'Available Months: ${availableMonths.length} | Selected: $selectedMonth',
            //         style: TextStyle(fontSize: 10, color: Colors.orange[900]),
            //       ),
            //     ],
            //   ),
            // ),

            // Info jumlah data
            if (!isLoading && filteredList.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  '${filteredList.length} data kehadiran',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ),

            // List Riwayat
            Expanded(
              child: isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Memuat data...'),
                        ],
                      ),
                    )
                  : filteredList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 80,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Tidak ada data kehadiran',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Total data di database: ${riwayatList.length}',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Cek debug console untuk detail',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: fetchRiwayatAbsensi,
                                icon: const Icon(Icons.refresh, color: Colors.white),
                                label: const Text('Refresh', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7C933F),
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: fetchRiwayatAbsensi,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              final item = filteredList[index];
                              final DateTime tanggal = item['tanggal'];
                              final String status = item['status'];
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: status == 'Cuti'
                                        ? Colors.orange.withOpacity(0.3)
                                        : Colors.green.withOpacity(0.3),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      // Tanggal
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: status == 'Cuti'
                                              ? Colors.orange.withOpacity(0.1)
                                              : Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              tanggal.day.toString(),
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: status == 'Cuti'
                                                    ? Colors.orange[700]
                                                    : Colors.green[700],
                                              ),
                                            ),
                                            Text(
                                              DateFormat('MMM', 'id_ID').format(tanggal),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: status == 'Cuti'
                                                    ? Colors.orange[700]
                                                    : Colors.green[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      const SizedBox(width: 16),
                                      
                                      // Detail
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Hari dan Tahun
                                            Text(
                                              DateFormat('EEEE, yyyy', 'id_ID').format(tanggal),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            
                                            // Status
                                            if (status == 'Cuti') ...[
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.event_busy,
                                                    size: 16,
                                                    color: Colors.orange[700],
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    item['kategoriCuti'] ?? 'Cuti',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.orange[700],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ] else ...[
                                              // Hadir - Jam Masuk & Keluar
                                              Row(
                                                children: [
                                                  // Jam Masuk
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              Icons.login,
                                                              size: 14,
                                                              color: Colors.grey[600],
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              'Masuk',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors.grey[600],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          item['jamMasuk'] ?? '-',
                                                          style: const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.green,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  
                                                  // Divider
                                                  Container(
                                                    height: 40,
                                                    width: 1,
                                                    color: Colors.grey[300],
                                                    margin: const EdgeInsets.symmetric(horizontal: 12),
                                                  ),
                                                  
                                                  // Jam Keluar
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              Icons.logout,
                                                              size: 14,
                                                              color: Colors.grey[600],
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              'Keluar',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors.grey[600],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 4),
                                                        
                                                          Text(
                                                          item['jamKeluar'] ?? '-',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.red[600],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
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