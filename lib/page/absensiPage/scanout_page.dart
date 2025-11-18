import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kebunsalak_app/config/config.dart';

class ScanOutPage extends StatefulWidget {
  const ScanOutPage({super.key});

  @override
  State<ScanOutPage> createState() => _ScanOutPageState();
}

class _ScanOutPageState extends State<ScanOutPage> {
  String? scannedResult;
  bool isScanned = false;
  double? distanceFromCenter;
  String selectedDate = '';
  String? selectedTime;

  // final url = Uri.parse("http://10.0.2.2:8000/api/absensi/out");
  final url = Uri.parse("${Config.apiUrl}/api/absensi/out");
  static const validQrUrl = "https://qrco.de/kbsk01";

  final double centerLat = -8.399575295800235;
  final double centerLng = 115.06402603222142;
  final double allowedRadiusMeters = 100;

  @override
  void initState() {
    super.initState();
    loadSelectedDate();
    loadSelectedTime(); // Load time from SharedPreferences
  }

  // Load tanggal dari SharedPreferences atau gunakan tanggal hari ini jika belum ada
  void loadSelectedDate() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedDate = prefs.getString('selected_date');
    if (savedDate == null) {
      savedDate = DateTime.now().toIso8601String().split("T").first;
      await prefs.setString('selected_date', savedDate);
    }
    if (mounted) {
      setState(() {
        selectedDate = savedDate!;
      });
    }
  }

  // Load waktu dari SharedPreferences
  void loadSelectedTime() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedTime = prefs.getString('selected_time');
    if (savedTime != null) {
      setState(() {
        selectedTime = savedTime;
      });
    } else {
      selectedTime = null; // Jika tidak ada, maka waktu akan diambil dari waktu real-time
    }
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
        title: const Text("Absen Keluar Menggunakan Link"),
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

              // Gunakan waktu yang diambil dari SharedPreferences atau real-time jika tidak ada
              String waktu = selectedTime ?? TimeOfDay.now().format(context);

              await sendAbsensiOut(
                idKaryawan: idKaryawan,
                nama: nama,
                jabatan: jabatan,
                tanggal: selectedDate,
                waktu: waktu,
                qrContent: inputLink,
              );

              await prefs.setString('scan_out_date', selectedDate);
              await prefs.setString('scan_out_time', waktu);
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
    isScanned = true; // Tandai pemindaian pertama
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
      isScanned = false; // Reset isScanned jika lokasi tidak valid
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
        isScanned = false; // Reset isScanned jika QR tidak valid
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
        isScanned = false; // Reset isScanned jika tidak ada data user
      });
      return;
    }

    setState(() {
      scannedResult = qrContent;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("QR berhasil discan.")),
    );

    // Gunakan waktu yang diambil dari SharedPreferences atau real-time jika tidak ada
    String waktu = selectedTime ?? TimeOfDay.now().format(context); // Ambil waktu yang benar

    await sendAbsensiOut(
      idKaryawan: idKaryawan,
      nama: nama,
      jabatan: jabatan,
      tanggal: selectedDate,
      waktu: waktu,
      qrContent: qrContent,
    );

    // Simpan waktu dan tanggal untuk keperluan absensi keluar
    await prefs.setString('scan_out_date', selectedDate);
    await prefs.setString('scan_out_time', waktu);

    await Future.delayed(const Duration(seconds: 3)); // Delay untuk memastikan tidak ada pemindaian ganda
    if (mounted) {
      setState(() {
        isScanned = false; // Reset flag setelah beberapa detik
        scannedResult = null; // Reset hasil scan
      });
    }
  } else {
    setState(() {
      isScanned = false; // Reset flag jika QR tidak valid
    });
  }
}


  Future<void> sendAbsensiOut({
    required String idKaryawan,
    required String nama,
    required String jabatan,
    required String tanggal,
    required String waktu,
    required String qrContent,
  }) async {
    try {
      final status = 'out';
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
        final errorData = jsonDecode(response.body);
        String errorMessage = errorData['message'] ?? 'Gagal absen keluar';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ $errorMessage")),
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
          "Presensi Keluar",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          const Text(
            "Scan QR Code yang sudah tersedia untuk melakukan presensi keluar",
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
