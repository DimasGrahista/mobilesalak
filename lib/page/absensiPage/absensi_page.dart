import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kebunsalak_app/page/absensiPage/scanin_page.dart';
import 'package:kebunsalak_app/page/absensiPage/scanout_page.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kebunsalak_app/service/app_data.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:kebunsalak_app/config/config.dart';

class AbsensiPage extends StatefulWidget {
  const AbsensiPage({super.key});

  @override
  State<AbsensiPage> createState() => _AbsensiPageState();
}

class _AbsensiPageState extends State<AbsensiPage> {
  String nama = '';
  String jabatan = '';
  String? formattedDate = '';  // Nullable formattedDate
  DateTime selectedDate = DateTime.now();
  String kegiatan = 'Perawatan'; // Default kegiatan
  DateTime selectedTime = DateTime.now(); // Default waktu sekarang
  String formattedTime = '';  // Untuk menampilkan waktu yang sudah diformat

  final bool isTesting = true; // mode test
  // final bool isTesting = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) async {
      DateTime? savedDate = await AppData.getSelectedDate();
      setState(() {
        selectedDate = savedDate ?? DateTime.now();
        formattedDate =
            DateFormat('d MMMM yyyy', 'id_ID').format(selectedDate);
      });
    });
    _loadUserInfo();
    _loadTimeFromSharedPreferences(); // Load waktu dari SharedPreferences
    _fetchJadwal(); // Fetch jadwal from API
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      nama = prefs.getString('nama') ?? 'User';
      jabatan = prefs.getString('jabatan') ?? '';
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        formattedDate =
            DateFormat('d MMMM yyyy', 'id_ID').format(selectedDate);
      });
      await AppData.saveSelectedDate(picked);
      _fetchJadwal(); // Fetch jadwal when date is changed
    }
  }

  // Future<void> _resetDateToToday() async {
  //   setState(() {
  //     selectedDate = DateTime.now();
  //     formattedDate =
  //         DateFormat('d MMMM yyyy', 'id_ID').format(selectedDate);
  //     // Set waktu real-time Asia/Jakarta saat reset
  //     selectedTime = DateTime.now();  // Set waktu real-time saat ini
  //     formattedTime = DateFormat('HH:mm').format(selectedTime);  // Menampilkan waktu yang diformat
  //   });

  //   // Save the current time as real-time in SharedPreferences
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setString('selected_time', formattedTime);

  //   await AppData.clearSelectedDate();
  //   _fetchJadwal(); // Fetch jadwal when reset to today
  // }
  
  Future<void> _resetDateToToday() async {
    setState(() {
      selectedDate = DateTime.now();
      formattedDate = DateFormat('d MMMM yyyy', 'id_ID').format(selectedDate);
      
      // Set waktu real-time saat reset
      selectedTime = DateTime.now();  // Waktu real-time saat ini
      formattedTime = DateFormat('HH:mm').format(selectedTime);  // Format waktu real-time
    });

    // Simpan waktu saat ini ke SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_time', formattedTime);  // Simpan waktu real-time

    await AppData.clearSelectedDate();
    _fetchJadwal(); // Fetch jadwal setelah reset ke hari ini
  }

  // Pick Time and Save to SharedPreferences
  Future<void> _pickTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedTime),
    );

    if (pickedTime != null) {
      setState(() {
        // Set waktu yang dipilih
        selectedTime = DateTime(selectedTime.year, selectedTime.month, selectedTime.day, pickedTime.hour, pickedTime.minute);
        formattedTime = DateFormat('HH:mm').format(selectedTime);  // Menampilkan waktu yang diformat
      });

      // Save the selected time in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_time', formattedTime);

      // Debug: Print the stored time from SharedPreferences
      debugPrint("Selected time saved in SharedPreferences: $formattedTime");
    }
  }

  // Load Time from SharedPreferences
  // Future<void> _loadTimeFromSharedPreferences() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   String? savedTime = prefs.getString('selected_time');
  //   if (savedTime != null) {
  //     setState(() {
  //       formattedTime = savedTime;
  //       selectedTime = DateFormat('HH:mm').parse(savedTime);
  //     });
  //     debugPrint("Loaded Time from SharedPreferences: $formattedTime");
  //   }
  // }

  Future<void> _loadTimeFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedTime = prefs.getString('selected_time');
    
    if (savedTime != null && savedTime.isNotEmpty) {
      // Jika ada waktu yang disimpan, gunakan waktu tersebut
      setState(() {
        formattedTime = savedTime;
        selectedTime = DateFormat('HH:mm').parse(savedTime); // Parse waktu yang disimpan
      });
      debugPrint("Loaded Time from SharedPreferences: $formattedTime");
    } else {
      // Jika tidak ada waktu yang disimpan, gunakan waktu real-time
      setState(() {
        selectedTime = DateTime.now();
        formattedTime = DateFormat('HH:mm').format(selectedTime); // Waktu real-time
      });
      debugPrint("No time saved, using current time: $formattedTime");
    }
  }


  // Fetch jadwal perawatan from API
  Future<void> _fetchJadwal() async {
    try {
      // Ambil tanggal yang dipilih dalam format yang sesuai dengan format tanggal API
      String selectedDateString = DateFormat('yyyy-MM-dd').format(selectedDate);

      // final response = await http.get(Uri.parse('http://10.0.2.2:8000/api/jadwals'));
      final response = await http.get(Uri.parse('${Config.apiUrl}/api/jadwals'));
      
      if (response.statusCode == 200) {
        final List jadwals = json.decode(response.body);

        // Filter jadwal berdasarkan tanggal yang dipilih
        var filteredJadwal = jadwals.firstWhere(
          (jadwal) {
            // Membandingkan tanggal jadwal dari API dengan tanggal yang dipilih
            String jadwalDate = jadwal['tanggal_jadwal']; // Misalnya '2025-05-28'
            return jadwalDate == selectedDateString; // Bandingkan string tanggal
          },
          orElse: () => null, // Jika tidak ada jadwal yang cocok
        );

        setState(() {
          // Tampilkan tugas jika ditemukan, jika tidak tampilkan 'Perawatan' sebagai default
          kegiatan = filteredJadwal != null ? filteredJadwal['tugas'] : 'Perawatan';
        });
      } else {
        setState(() {
          kegiatan = 'Gagal memuat jadwal';
        });
      }
    } catch (e) {
    if (!mounted) return;
      setState(() {
        kegiatan = 'Terjadi kesalahan saat mengambil jadwal';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header dinamis
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF5E762F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Halo, $nama 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      jabatan,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tombol testing ubah tanggal dan reset tanggal
              if (isTesting)
                Center(
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Ubah Tanggal (Testing)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12), // jarak antar tombol
                      ElevatedButton.icon(
                        onPressed: _resetDateToToday,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset Tanggal'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.access_time),
                        label: const Text('Ubah Waktu (Testing)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Info tanggal & kegiatan
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tanggal', style: TextStyle(fontSize: 12)),
                    Text(
                      formattedDate!,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text('Kegiatan', style: TextStyle(fontSize: 12)),
                    Text(
                      kegiatan, // Tampilkan kegiatan dari API
                      style:
                          const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text('Waktu', style: TextStyle(fontSize: 12)),
                    Text(
                      formattedTime.isEmpty ? 'Pilih Waktu' : formattedTime,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const ScanInPage()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color.fromARGB(255, 47, 158, 51),
                                minimumSize: const Size(120, 44),
                              ),
                              child: const Text('Scan In',
                                  style: TextStyle(color: Colors.white)),
                            ),
                            const SizedBox(height: 4),
                            const Text('06:00 - 08:00',
                                style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        const SizedBox(width: 32),
                        Column(
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const ScanOutPage()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color.fromARGB(255, 181, 31, 26),
                                minimumSize: const Size(120, 44),
                              ),
                              child: const Text('Scan Out',
                                  style: TextStyle(color: Colors.white)),
                            ),
                            const SizedBox(height: 4),
                            const Text('17:00 - 18:00',
                                style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ],  
                ),
              ),
              const SizedBox(height: 24),

              const TutorialCard(
                title: 'Tutorial Perawatan',
                description:
                    'Untuk mencegah hama pada kebun salak, lakukan pemangkasan rutin, jaga kebersihan lingkungan, dan aplikasikan insektisida organik secara berkala.',
              ),
              const SizedBox(height: 12),
              const TutorialCard(
                title: 'Prosedur Panen dan Pascapanen Tanaman Salak',
                description:
                    'Panduan tentang prosedur panen yang tepat, teknik pemanenan yang aman, serta penanganan pascapanen untuk menjaga kualitas hasil salak.',
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class TutorialCard extends StatelessWidget {
  final String title;
  final String description;

  const TutorialCard({
    super.key,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color.fromARGB(255, 224, 224, 224)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
