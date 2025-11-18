import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http; 
import 'dart:convert'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart'; 
import 'package:kebunsalak_app/config/config.dart';


class PengajuanCutiPage extends StatefulWidget {
  const PengajuanCutiPage({Key? key}) : super(key: key);

  @override
  State<PengajuanCutiPage> createState() => _PengajuanCutiPageState();
}

class _PengajuanCutiPageState extends State<PengajuanCutiPage> {
  final TextEditingController _kategoriController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController(); 
  final TextEditingController _tanggalMulaiController = TextEditingController();
  final TextEditingController _tanggalSelesaiController = TextEditingController();
  File? _image; 
  final ImagePicker _picker = ImagePicker();

  int sisaCuti = 12;

  // Mengambil ID Karyawan yang disimpan dan kemudian mendapatkan sisa cuti
  Future<void> _getSisaCuti() async {
  final idKaryawan = await _getIdKaryawan();
  final token = await _getToken();  // Ambil token dari SharedPreferences
  
  if (idKaryawan != null && token != null) {
    // final url = 'http://10.0.2.2:8000/api/cuti/sisa/$idKaryawan';
    final url = '${Config.apiUrl}/api/cuti/sisa/$idKaryawan';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',  // Mengirimkan token di header
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          sisaCuti = data['sisa_cuti'];
        });
      }  
        else {
        debugPrint("Failed to fetch sisa cuti. Status code: ${response.statusCode}");
        // Periksa apakah widget masih terpasang sebelum memanggil setState atau menggunakan BuildContext
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat sisa cuti')),
        );
      }
    } catch (e) {
      debugPrint("Error fetching sisa cuti: $e");
        if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
    }
  }
}


  @override
  void initState() {
    super.initState();
    _getSisaCuti();  // Memanggil _getSisaCuti tanpa ID hardcoded
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<String?> _getIdKaryawan() async {
    final prefs = await SharedPreferences.getInstance();
    String? idKaryawan = prefs.getString('id_karyawan');
    debugPrint("ID Karyawan: $idKaryawan"); // Debugging ID Karyawan
    return idKaryawan;
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(pickedDate);
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
  }

  Future<void> _submitCuti() async {
    String kategori = _kategoriController.text;
    String tanggalMulai = _tanggalMulaiController.text;
    String tanggalSelesai = _tanggalSelesaiController.text;
    String keterangan = _keteranganController.text;

    // Debugging untuk memastikan input yang diterima
    debugPrint("Kategori: $kategori, Tanggal Mulai: $tanggalMulai, Tanggal Selesai: $tanggalSelesai, Keterangan: $keterangan");

    if (kategori.isNotEmpty && tanggalMulai.isNotEmpty && tanggalSelesai.isNotEmpty) {
      // Hitung jumlah hari cuti yang diajukan
      DateTime startDate = DateFormat('yyyy-MM-dd').parse(tanggalMulai);
      DateTime endDate = DateFormat('yyyy-MM-dd').parse(tanggalSelesai);
      int daysRequested = endDate.difference(startDate).inDays + 1;

      // Debugging jumlah cuti yang diajukan
      debugPrint("Days requested: $daysRequested");

      // Debugging sisa kuota cuti
      debugPrint("Sisa kuota yang tersisa: $sisaCuti");

      // Periksa apakah jumlah cuti yang diajukan melebihi sisa kuota
      if (daysRequested > sisaCuti) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengajuan cuti ditolak karena Anda melebihi batas kuota cuti'))
        );
        return; // Tidak melanjutkan jika melebihi kuota
      }

      String url = 'http://10.0.2.2:8000/api/cuti';

      try {
        final token = await _getToken();
        final idKaryawan = await _getIdKaryawan();

        if (token == null || idKaryawan == null) {
        if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Token atau ID karyawan tidak ditemukan. Silakan login ulang.'))
          );
          return;
        }

        var uri = Uri.parse(url);
        var request = http.MultipartRequest('POST', uri);

        // Debugging request sebelum dikirim
        debugPrint("Sending request with URL: $url");
        debugPrint("Headers: ${request.headers}");
        debugPrint("Fields: ${request.fields}");

        request.headers['Authorization'] = 'Bearer $token';
        request.headers['Accept'] = 'application/json';
        request.fields['id_karyawan'] = idKaryawan;
        request.fields['kategori'] = kategori;
        request.fields['tanggal_pengajuan'] = DateTime.now().toIso8601String();
        request.fields['tanggal_mulai'] = tanggalMulai;
        request.fields['tanggal_akhir'] = tanggalSelesai;
        request.fields['status_validasi'] = 'Pending';
        request.fields['keterangan'] = keterangan;

        if (_image != null) {
          var fotoFile = await http.MultipartFile.fromPath(
            'foto_bukti', _image!.path, contentType: MediaType('image', 'jpeg')
          );
          request.files.add(fotoFile);
        }

        var response = await request.send();

        // Debugging response dari server
        debugPrint("Response status: ${response.statusCode}");
        debugPrint("Response headers: ${response.headers}");

        if (response.statusCode == 201) {
        if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cuti berhasil diajukan'))
          );
          setState(() {
            _image = null;
            _kategoriController.clear();
            _keteranganController.clear();
          });
        } else {
        if (!mounted) return;

          // Tampilkan status error jika gagal
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengajukan cuti. Kode status: ${response.statusCode}'))
          );
          // Debugging response body jika gagal
          response.stream.bytesToString().then((value) {
            debugPrint("Error response body: $value");
          });
        }
      } catch (e) {
        debugPrint("Error submitting cuti: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e'))
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi kategori, tanggal mulai, dan tanggal selesai'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pengajuan Cuti'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Sisa Cuti Tahun Ini: $sisaCuti hari',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            SizedBox(height: 5),
            Text('Alasan Cuti', style: TextStyle(fontSize: 16)),
            TextField(
              controller: _kategoriController,
              decoration: _inputDecoration('Masukkan Alasan Cuti'),
            ),
            SizedBox(height: 10),
            Text('Keterangan Cuti', style: TextStyle(fontSize: 16)), 
            TextField(
              controller: _keteranganController,
              decoration: _inputDecoration('Masukkan Keterangan Cuti'),
              maxLines: 3,
            ),
            SizedBox(height: 10),
            Text('Pilih Tanggal Mulai', style: TextStyle(fontSize: 16)),
            TextField(
              controller: _tanggalMulaiController,
              decoration: _inputDecoration('Pilih Tanggal Mulai'),
              readOnly: true,
              onTap: () => _selectDate(context, _tanggalMulaiController),
            ),
            SizedBox(height: 10),
            Text('Pilih Tanggal Selesai', style: TextStyle(fontSize: 16)),
            TextField(
              controller: _tanggalSelesaiController,
              decoration: _inputDecoration('Pilih Tanggal Selesai'),
              readOnly: true,
              onTap: () => _selectDate(context, _tanggalSelesaiController),
            ),
            SizedBox(height: 10),
            GestureDetector(
              onTap: () => _showImageSourceActionSheet(context),
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                  image: _image != null
                      ? DecorationImage(image: FileImage(_image!), fit: BoxFit.cover)
                      : null,
                ),
                child: _image == null
                    ? const Center(child: Icon(Icons.add_a_photo, size: 50, color: Colors.grey))
                    : null,
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _submitCuti,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6F8313),
                  padding: EdgeInsets.symmetric(horizontal: 148, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text('Ajukan', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
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
        borderSide: const BorderSide(color: Colors.grey, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6F8313), width: 2),
      ),
    );
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Ambil dari Kamera'),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pilih dari Galeri'),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
