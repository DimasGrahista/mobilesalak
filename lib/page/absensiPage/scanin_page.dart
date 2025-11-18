import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kebunsalak_app/config/config.dart';

class ScanInPage extends StatefulWidget {
  const ScanInPage({super.key});

  @override
  State<ScanInPage> createState() => _ScanInPageState();
}

class _ScanInPageState extends State<ScanInPage> {
  String? scannedResult;
  bool isScanned = false;
  double? distanceFromCenter;

  final url = Uri.parse("${Config.apiUrl}/api/absensi/in");
  static const validQrUrl = "https://qrco.de/kbsk01";

  final double centerLat = -8.399575295800235;
  final double centerLng = 115.06402603222142;
  final double allowedRadiusMeters = 100;

  String? selectedDate;
  String? selectedTime;

  @override
  void initState() {
    super.initState();
    isWithinRadius();
    loadDate();
    loadTime(); // Load the selected time from SharedPreferences
  }

  // Load tanggal dari SharedPreferences atau gunakan tanggal hari ini jika belum ada
  void loadDate() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedDate = prefs.getString('selected_date');
    if (savedDate == null) {
      savedDate = DateTime.now().toIso8601String().split("T").first;
    }
    if (mounted) {
      setState(() {
        selectedDate = savedDate;
      });
    }
  }

  // Load waktu dari SharedPreferences
  void loadTime() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedTime = prefs.getString('selected_time');
    if (savedTime != null) {
      setState(() {
        selectedTime = savedTime;
      });
      debugPrint("Loaded Time from SharedPreferences: $selectedTime"); // Debugging loaded time
    }
  }

  // Simpan tanggal ke SharedPreferences
  Future<void> saveSelectedDate(String date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_date', date);
    if (mounted) {
      setState(() {
        selectedDate = date;
      });
    }
  }

  // Simpan waktu ke SharedPreferences
  Future<void> saveSelectedTime(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_time', time);
    if (mounted) {
      setState(() {
        selectedTime = time;
      });
    }
    debugPrint("Saved Time to SharedPreferences: $selectedTime"); // Debugging saved time
  }

  Future<bool> isWithinRadius() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      double distanceInMeters = Geolocator.distanceBetween(
        centerLat,
        centerLng,
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          distanceFromCenter = distanceInMeters;
        });
      }

      return distanceInMeters <= allowedRadiusMeters;
    } catch (e) {
      debugPrint('Error cek lokasi: $e');
      return false;
    }
  }

  void _showEmergencyDialog() {
    final TextEditingController linkController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Absen Menggunakan Link"),
        content: TextField(
          controller: linkController,
          decoration: const InputDecoration(
            labelText: "Masukkan link absensi",
            hintText: "https://...",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);

              final inputLink = linkController.text.trim();
              if (inputLink != validQrUrl) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Link yang dimasukkan tidak valid."),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              bool isValidLocation = await isWithinRadius();
              if (!mounted) return;
              if (!isValidLocation) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Kamu berada di luar area absensi yang diizinkan."),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final prefs = await SharedPreferences.getInstance();
              final idKaryawan = prefs.getString('id_karyawan');
              final nama = prefs.getString('nama') ?? '';
              final jabatan = prefs.getString('jabatan') ?? '';

              if (!mounted) return;
              if (idKaryawan == null || idKaryawan.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Data user tidak ditemukan. Silakan login terlebih dahulu."),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Debug: Print the time to be sent to the database
              debugPrint("Selected Time: $selectedTime");

              // Check if there is an approved leave on the same day
              bool isLeaveApproved = await checkIfLeaveApproved(selectedDate ?? DateTime.now().toIso8601String().split("T").first, idKaryawan);
              if (isLeaveApproved) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Cuti disetujui pada tanggal ini, tidak dapat absen."),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              await sendAbsensiData(
                idKaryawan: idKaryawan,
                nama: nama,
                jabatan: jabatan,
                tanggal: selectedDate ?? DateTime.now().toIso8601String().split("T").first,
                waktu: selectedTime ?? TimeOfDay.now().format(context),
                status: "in",
                qrContent: inputLink,
              );
            },
            child: const Text("Kirim"),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) async {
  if (isScanned) return; // Mencegah pemindaian ganda

  setState(() {
    isScanned = true; // Tandai pemindaian sudah dilakukan
  });

  bool isValidLocation = await isWithinRadius();
  if (!mounted) return;
  if (!isValidLocation) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Kamu berada di luar area absensi yang diizinkan."),
        backgroundColor: Colors.red,
      ),
    );
    setState(() {
      isScanned = false; // Reset isScanned
    });
    return;
  }

  final Barcode? barcode = capture.barcodes.firstOrNull;
  if (barcode != null && barcode.rawValue != null) {
    final qrContent = barcode.rawValue!;

    if (qrContent != validQrUrl) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("QR code tidak valid untuk absensi ini.")),
      );
      setState(() {
        isScanned = false; // Reset isScanned
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final idKaryawan = prefs.getString('id_karyawan');
    final nama = prefs.getString('nama') ?? '';
    final jabatan = prefs.getString('jabatan') ?? '';

    if (!mounted) return;
    if (idKaryawan == null || idKaryawan.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Data user tidak ditemukan. Silakan login terlebih dahulu."),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        isScanned = false; // Reset isScanned
      });
      return;
    }

    setState(() {
      scannedResult = qrContent;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("QR berhasil discan.")),
    );

    // Ambil waktu absensi
    String waktuAbsensi = selectedTime ?? TimeOfDay.now().format(context); // Gunakan waktu yang sudah disimpan
    debugPrint("Waktu yang dipilih untuk absensi: $waktuAbsensi"); // Debugging waktu yang dipilih

    // Cek apakah karyawan memiliki cuti yang disetujui pada tanggal ini
    bool isLeaveApproved = await checkIfLeaveApproved(selectedDate ?? DateTime.now().toIso8601String().split("T").first, idKaryawan);
    if (isLeaveApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cuti disetujui pada tanggal ini, tidak dapat absen."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Kirim data absensi ke server
    await sendAbsensiData(
      idKaryawan: idKaryawan,
      nama: nama,
      jabatan: jabatan,
      tanggal: selectedDate ?? DateTime.now().toIso8601String().split("T").first,
      waktu: waktuAbsensi, // Gunakan waktu yang sudah disimpan
      status: "in",
      qrContent: qrContent,
    );

    // Tunggu beberapa detik sebelum reset isScanned dan hasil scan
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      setState(() {
        isScanned = false; // Reset flag isScanned setelah beberapa detik
        scannedResult = null; // Reset hasil scan
      });
    }
  } else {
    setState(() {
      isScanned = false; // Reset isScanned jika barcode tidak valid
    });
  }
}


  // Check if there's an approved leave on the same date
  Future<bool> checkIfLeaveApproved(String tanggal, String idKaryawan) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/cuti/$idKaryawan'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final cutiData = jsonDecode(response.body);

        bool isCutiApproved = cutiData.any((item) {
          String startDate = item['tanggal_mulai'] ?? '';
          String endDate = item['tanggal_akhir'] ?? '';
          String statusValidasi = item['status_validasi'] ?? '';

          if (startDate.isEmpty || endDate.isEmpty) return false;

          DateTime formattedStartDate = DateTime.parse(startDate);
          DateTime formattedEndDate = DateTime.parse(endDate);
          DateTime formattedTanggal = DateTime.parse(tanggal);

          return formattedStartDate.isBefore(formattedTanggal.add(Duration(days: 1))) &&
                 formattedEndDate.isAfter(formattedTanggal.subtract(Duration(days: 1))) &&
                 statusValidasi == 'Approved';
        });

        return isCutiApproved;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('Error saat cek cuti: $e');
      return false;
    }
  }

  Future<void> sendAbsensiData({
    required String idKaryawan,
    required String nama,
    required String jabatan,
    required String tanggal,
    required String waktu,
    required String status,
    required String qrContent,
  }) async {
    try {
      final bodyData = {
        'id_karyawan': idKaryawan,
        'nama': nama,
        'jabatan': jabatan,
        'tanggal': tanggal,
        'waktu': waktu,
        'status': status,
        'qr_content': qrContent,
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(bodyData),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ ${data['message']}")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Gagal absen. Status: ${response.statusCode}")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Terjadi kesalahan: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          "Presensi Masuk",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          const Text(
            "Scan QR Code yang sudah tersedia untuk melakukan presensi",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
          if (distanceFromCenter != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "Jarak ke titik absen: ${distanceFromCenter!.toStringAsFixed(2)} meter",
                style: TextStyle(
                  fontSize: 14,
                  color: distanceFromCenter! <= allowedRadiusMeters
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: MobileScanner(
              controller: MobileScannerController(),
              onDetect: _onDetect,
            ),
          ),
          const SizedBox(height: 8),
          if (scannedResult != null)
            const Text("Scan berhasil!", style: TextStyle(fontSize: 16)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _showEmergencyDialog,
              icon: const Icon(Icons.link, color: Colors.white),
              label: const Text(
                "Absen Link",
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E762F),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
