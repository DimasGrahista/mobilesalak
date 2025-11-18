import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:http/http.dart' as http; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';
import 'package:kebunsalak_app/config/config.dart';

class PanenPage extends StatefulWidget {
  const PanenPage({Key? key}) : super(key: key);

  @override
  State<PanenPage> createState() => PanenPageState();
}

class PanenPageState extends State<PanenPage> {
  final TextEditingController _tanggalPanenController = TextEditingController();
  final TextEditingController _blokLahanController = TextEditingController();
  final TextEditingController _jumlahController = TextEditingController();
  String _kualitas = 'Baik'; // Default value for quality
  File? _image; 
  final ImagePicker _picker = ImagePicker();

  // List of quality options
  final List<String> _kualitasOptions = ['Baik', 'Sedang', 'Kurang'];

  Future<void> _submitPanen() async {
    String tanggalPanen = _tanggalPanenController.text;
    String blokLahan = _blokLahanController.text;
    String jumlah = _jumlahController.text;
    String kualitas = _kualitas;

    // Mengambil ID Karyawan yang disimpan
    final idKaryawan = await _getIdKaryawan();

    if (tanggalPanen.isNotEmpty && blokLahan.isNotEmpty && jumlah.isNotEmpty && kualitas.isNotEmpty) {
      try {
        final token = await _getToken();

        if (token == null || idKaryawan == null) {
        if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Token atau ID karyawan tidak ditemukan. Silakan login ulang.'))
          );
          return;
        }

        var url = Uri.parse('${Config.apiUrl}/api/harvests');
        var request = http.MultipartRequest('POST', url);
        request.headers['Authorization'] = 'Bearer $token';
        request.headers['Accept'] = 'application/json';
        request.fields['id_karyawan'] = idKaryawan; 
        request.fields['tanggal_panen'] = tanggalPanen;
        request.fields['blok_lahan'] = blokLahan;
        request.fields['jumlah_kg'] = jumlah;
        request.fields['kualitas_panen'] = kualitas;

        if (_image != null) {
          var fotoFile = await http.MultipartFile.fromPath(
            'foto_bukti', _image!.path, contentType: MediaType('image', 'jpeg')
          );
          request.files.add(fotoFile);
        }

        var response = await request.send();

        if (response.statusCode == 201) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Panen berhasil diajukan'))
          );
          setState(() {
            _image = null;
            _tanggalPanenController.clear();
            _blokLahanController.clear();
            _jumlahController.clear();
          });
        } else {
        if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengajukan panen. Kode status: ${response.statusCode}'))
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e'))
        );
      }
    } else {
        if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi semua field'))
      );
    }
  }


  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<String?> _getIdKaryawan() async {
    final prefs = await SharedPreferences.getInstance();
    String? idKaryawan = prefs.getString('id_karyawan');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Input Panen'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Tanggal Panen', style: TextStyle(fontSize: 16)),
            TextField(
              controller: _tanggalPanenController,
              decoration: _inputDecoration('Pilih Tanggal Panen'),
              readOnly: true,
              onTap: () => _selectDate(context, _tanggalPanenController),
            ),
            SizedBox(height: 10),
            Text('Blok Lahan', style: TextStyle(fontSize: 16)),
            TextField(
              controller: _blokLahanController,
              decoration: _inputDecoration('Masukkan Blok Lahan'),
            ),
            SizedBox(height: 10),
            Text('Jumlah Panen (Kg)', style: TextStyle(fontSize: 16)),
            TextField(
              controller: _jumlahController,
              decoration: _inputDecoration('Masukkan Jumlah Panen (Kg)'),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 10),
            Text('Kualitas Panen', style: TextStyle(fontSize: 16)),
            InputDecorator(
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF6F8313), width: 1),
                ),
              ),
              child: DropdownButton<String>(
                value: _kualitas,
                isExpanded: true,
                icon: Icon(Icons.arrow_downward),
                elevation: 16,
                style: TextStyle(color: Colors.black),
                onChanged: (String? newValue) {
                  setState(() {
                    _kualitas = newValue!;
                  });
                },
                items: _kualitasOptions.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
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
                onPressed: _submitPanen,
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
