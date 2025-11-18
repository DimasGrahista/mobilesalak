import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer'; // ← Tambahkan ini
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kebunsalak_app/page/home/home_page.dart';
import 'package:kebunsalak_app/config/config.dart';
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _message = '';

  Future<void> _login() async {
    final username = _usernameController.text;
    final password = _passwordController.text;

    // final url = Uri.parse('http://10.0.2.2:8000/api/login');
    // final url = Uri.parse('https://ddccfbce1f89.ngrok-free.app/api/login');
    final url = Uri.parse('${Config.apiUrl}/api/login');  // Menggunakan ngrok

    try {
      final response = await http.post(
        url,
        headers: {'Accept': 'application/json'},
        body: {
          'username_kar': username,
          'password_kar': password,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        log("Response body: ${response.body}");
        log("Parsed data: $data");

        final karyawan = data['karyawan'];

        if (karyawan != null && karyawan['id_karyawan'] != null) {
          final prefs = await SharedPreferences.getInstance();

          await prefs.setString('token', data['token'] ?? '');
          await prefs.setString('id_karyawan', karyawan['id_karyawan'].toString());
          await prefs.setString('nama', karyawan['nama_kar'] ?? '');
          await prefs.setString('username', karyawan['username_kar'] ?? '');
          await prefs.setString('jabatan', karyawan['jabatan'] ?? '');

          log("Data berhasil disimpan ke SharedPreferences.");

          if (!mounted) return;
          setState(() {
            _message = 'Login berhasil!';
          });

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        } else {
          log("Karyawan data null atau ID null!");
          if (!mounted) return;
          setState(() {
            _message = 'Login gagal: data tidak lengkap';
          });
        }

      } else {
        final errorData = json.decode(response.body);
        log("Login gagal: ${errorData['message']}");
        if (!mounted) return;
        setState(() {
          _message = errorData['message'] ?? 'Login gagal';
        });
      }
    } catch (e) {
      log("Error koneksi atau parsing: $e");
      if (!mounted) return;
      setState(() {
        _message = 'Terjadi kesalahan koneksi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo-02-basic.png',
              width: 130,
              height: 130,
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                labelStyle: TextStyle(color: Color(0xFF5E762F)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF5E762F)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(color: Color(0xFF5E762F)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF5E762F)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_message.isNotEmpty)
              Text(
                _message,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5E762F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _login,
                child: const Text(
                  'Log In',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
