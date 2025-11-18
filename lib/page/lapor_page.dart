import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:kebunsalak_app/config/config.dart';

class LaporPage extends StatefulWidget {
  const LaporPage({super.key});

  @override
  State<LaporPage> createState() => _LaporPageState();
}

class _LaporPageState extends State<LaporPage> {
  File? _image;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _kategoriController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();

  DateTime? selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSelectedDate();
  }

  Future<void> _loadSelectedDate() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedDateStr = prefs.getString('selected_date');
    if (savedDateStr != null) {
      setState(() {
        selectedDate = DateTime.parse(savedDateStr);
      });
    } else {
      setState(() {
        selectedDate = DateTime.now();
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  bool _isSheetOpen = false;

  void _showImageSourceActionSheet(BuildContext context) {
    if (_isSheetOpen) return;
    _isSheetOpen = true;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Ambil dari Kamera'),
                onTap: () => _pickImage(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pilih dari Galeri'),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() => _isSheetOpen = false);
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<String?> _getIdKaryawan() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('id_karyawan'); // Pastikan kamu simpan ini saat login
  }

  Future<void> _submitLaporan() async {
    final kategori = _kategoriController.text;
    final keterangan = _keteranganController.text;

    if (_image != null && kategori.isNotEmpty && keterangan.isNotEmpty && selectedDate != null) {
      setState(() => _isLoading = true);

      try {
        final token = await _getToken();
        final idKaryawan = await _getIdKaryawan();

        if (token == null || idKaryawan == null) {
        if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Token atau ID karyawan tidak ditemukan. Silakan login ulang.')),
          );
          setState(() => _isLoading = false);
          return;
        }

        final uri = Uri.parse('${Config.apiUrl}/api/laporan');  /////URL
        final request = http.MultipartRequest('POST', uri)
          ..headers['Authorization'] = 'Bearer $token'
          ..headers['Accept'] = 'application/json'
          ..fields['id_karyawan'] = idKaryawan
          ..fields['judul_laporan'] = kategori
          ..fields['uraian_kegiatan'] = keterangan
          ..fields['created_at'] = selectedDate!.toIso8601String();

        request.files.add(await http.MultipartFile.fromPath('foto_kegiatan', _image!.path));

        final response = await request.send();

        if (response.statusCode == 200) {
        if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Laporan berhasil dikirim')),
          );
          setState(() {
            _image = null;
            _kategoriController.clear();
            _keteranganController.clear();
          });
        } else {
        if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengirim laporan. Kode: ${response.statusCode}')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi semua data')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = selectedDate != null
        ? DateFormat('dd MMMM yyyy').format(selectedDate!)
        : 'Memuat tanggal...';

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Laporan Kebun',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Silakan isi laporan kegiatan di kebun Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 20),

              Text(
                'Tanggal Laporan: $formattedDate',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),

              GestureDetector(
                onTap: () => _showImageSourceActionSheet(context),
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                    image: _image != null
                        ? DecorationImage(
                            image: FileImage(_image!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _image == null
                      ? const Center(
                          child: Icon(Icons.add_a_photo, size: 50, color: Colors.grey))
                      : null,
                ),
              ),

              const SizedBox(height: 24),

              Align(
                alignment: Alignment.centerLeft,
                child: Text('Kategori', style: _labelStyle()),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _kategoriController,
                decoration: _inputDecoration('Masukkan kategori laporan'),
              ),

              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerLeft,
                child: Text('Keterangan', style: _labelStyle()),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _keteranganController,
                maxLines: 5,
                decoration: _inputDecoration('Tulis keterangan laporan'),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E762F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: _isLoading ? null : _submitLaporan,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Lapor', style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _labelStyle() {
    return const TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );
  }

  InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.grey, width: 1),  // border terlihat
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.grey, width: 1), // border normal
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color.fromARGB(255, 29, 158, 34), width: 2), // border saat fokus
    ),
  );
}

}
