import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String _baseUrl = 'http://localhost/kebunsalak_api/login.php'; // sesuaikan dengan URL API-mu

  // Fungsi login
  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      body: {
        'username': username,
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body); // Mengembalikan hasil JSON
    } else {
      throw Exception('Failed to login');
    }
  }
}
