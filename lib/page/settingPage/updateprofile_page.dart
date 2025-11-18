import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kebunsalak_app/config/config.dart';

class UpdateProfilePage extends StatefulWidget {
  const UpdateProfilePage({super.key});

  @override
  State<UpdateProfilePage> createState() => _UpdateProfilePageState();
}

class _UpdateProfilePageState extends State<UpdateProfilePage> {
  String nama = '';
  String jabatan = '';

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _alamatController = TextEditingController();
  final TextEditingController _noHpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _verifPasswordController = TextEditingController();

  final String baseUrl = '${Config.apiUrl}/api';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // Memuat data profil dari SharedPreferences dan API
  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final idKaryawan = prefs.getString('id_karyawan') ?? '';

    if (idKaryawan.isNotEmpty) {
      final response = await http.get(
        Uri.parse('$baseUrl/get_profile?id_karyawan=$idKaryawan'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          nama = data['nama_kar'] ?? '';
          jabatan = data['jabatan'] ?? '';
          _emailController.text = data['email'] ?? '';
          _alamatController.text = data['alamat'] ?? '';
          _noHpController.text = data['no_hp'] ?? '';
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat profil')),
        );
      }
    }
  }

  // Fungsi untuk mengirim perubahan data ke backend
  Future<void> _updateProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final idKaryawan = prefs.getString('id_karyawan') ?? '';

    final passwordBaru = _passwordController.text;
    final verifPassword = _verifPasswordController.text;

    if (passwordBaru.isNotEmpty && passwordBaru != verifPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password tidak sama')),
      );
      return;
    }

    final body = {
      'id_karyawan': idKaryawan,
      'email': _emailController.text,
      'alamat': _alamatController.text,
      'no_hp': _noHpController.text,
    };

    if (passwordBaru.isNotEmpty) {
      body['password'] = passwordBaru;
      body['password_confirmation'] = verifPassword;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/update_profile'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(body),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['message'] == 'success') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui')),
      );
      await _loadProfile();
      _passwordController.clear();
      _verifPasswordController.clear();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui profil: ${data['message'] ?? 'Unknown error'}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pengaturan Profil"),
        backgroundColor: const Color(0xFF5E762F),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF5E762F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nama, style: const TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 4),
                Text(jabatan, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildTextField("Email", _emailController, TextInputType.emailAddress),
          _buildTextField("Alamat", _alamatController, TextInputType.text),
          _buildTextField("No HP", _noHpController, TextInputType.phone),
          const SizedBox(height: 20),
          const Text("Ganti Password", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildTextField("Password Baru", _passwordController, TextInputType.visiblePassword, obscureText: true),
          _buildTextField("Verifikasi Password", _verifPasswordController, TextInputType.visiblePassword, obscureText: true),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _updateProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5E762F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Simpan Perubahan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    TextInputType keyboardType, {
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
