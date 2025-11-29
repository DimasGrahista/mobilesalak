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

  Future<void> _getSisaCuti() async {
    final idKaryawan = await _getIdKaryawan();
    final token = await _getToken();
    
    if (idKaryawan != null && token != null) {
      final url = '${Config.apiUrl}/api/cuti/sisa/$idKaryawan';
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            sisaCuti = data['sisa_cuti'];
          });
        } else {
          debugPrint("Failed to fetch sisa cuti. Status code: ${response.statusCode}");
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal memuat sisa cuti')),
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
    _getSisaCuti();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<String?> _getIdKaryawan() async {
    final prefs = await SharedPreferences.getInstance();
    String? idKaryawan = prefs.getString('id_karyawan');
    debugPrint("ID Karyawan: $idKaryawan");
    return idKaryawan;
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF5E762F),
              onPrimary: Colors.white,
              onSurface: Color(0xFF2D3436),
            ),
          ),
          child: child!,
        );
      },
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

    debugPrint("Kategori: $kategori, Tanggal Mulai: $tanggalMulai, Tanggal Selesai: $tanggalSelesai, Keterangan: $keterangan");

    if (kategori.isNotEmpty && tanggalMulai.isNotEmpty && tanggalSelesai.isNotEmpty) {
      DateTime startDate = DateFormat('yyyy-MM-dd').parse(tanggalMulai);
      DateTime endDate = DateFormat('yyyy-MM-dd').parse(tanggalSelesai);
      int daysRequested = endDate.difference(startDate).inDays + 1;

      debugPrint("Days requested: $daysRequested");
      debugPrint("Sisa kuota yang tersisa: $sisaCuti");

      if (daysRequested > sisaCuti) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengajuan cuti ditolak karena Anda melebihi batas kuota cuti'))
        );
        return;
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

        debugPrint("Response status: ${response.statusCode}");
        debugPrint("Response headers: ${response.headers}");

        if (response.statusCode == 201) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cuti berhasil diajukan'))
          );
          setState(() {
            _image = null;
            _kategoriController.clear();
            _keteranganController.clear();
            _tanggalMulaiController.clear();
            _tanggalSelesaiController.clear();
          });
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengajukan cuti. Kode status: ${response.statusCode}'))
          );
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3436)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pengajuan Cuti',
          style: TextStyle(
            color: Color(0xFF2D3436),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Sisa Cuti Card
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5E762F), Color(0xFF7C933F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5E762F).withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.beach_access_outlined,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sisa Cuti Tahun Ini',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$sisaCuti',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: Text(
                                'hari',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Form Container
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Alasan Cuti'),
                  const SizedBox(height: 2),
                  _buildTextField(
                    controller: _kategoriController,
                    hint: 'Masukkan alasan cuti',
                    icon: Icons.category_outlined,
                  ),
                  const SizedBox(height: 10),

                  _buildLabel('Keterangan'),
                  const SizedBox(height: 2),
                  _buildTextField(
                    controller: _keteranganController,
                    hint: 'Masukkan keterangan tambahan',
                    icon: Icons.description_outlined,
                  ),
                  const SizedBox(height: 10),

                  _buildLabel('Tanggal Mulai'),
                  const SizedBox(height: 2),
                  _buildDateField(
                    controller: _tanggalMulaiController,
                    hint: 'Pilih tanggal mulai',
                  ),
                  const SizedBox(height: 10),

                  _buildLabel('Tanggal Selesai'),
                  const SizedBox(height: 2),
                  _buildDateField(
                    controller: _tanggalSelesaiController,
                    hint: 'Pilih tanggal selesai',
                  ),
                  const SizedBox(height: 10),

                  _buildLabel('Foto Bukti (Opsional)'),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () => _showImageSourceActionSheet(context),
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: _image != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(
                                    _image!,
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5E762F).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 40,
                                    color: Color(0xFF5E762F),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Tambah Foto',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF636E72),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Ketuk untuk memilih foto',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _submitCuti,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E762F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Ajukan Cuti',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF2D3436),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF5E762F), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: controller,
        readOnly: true,
        style: const TextStyle(fontSize: 14),
        onTap: () => _selectDate(context, controller),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: const Icon(
            Icons.calendar_today_outlined,
            color: Color(0xFF5E762F),
            size: 20,
          ),
          suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Pilih Sumber Foto',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5E762F).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: Color(0xFF5E762F),
                    ),
                  ),
                  title: const Text('Ambil dari Kamera'),
                  onTap: () {
                    _pickImage(ImageSource.camera);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5E762F).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      color: Color(0xFF5E762F),
                    ),
                  ),
                  title: const Text('Pilih dari Galeri'),
                  onTap: () {
                    _pickImage(ImageSource.gallery);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }
}