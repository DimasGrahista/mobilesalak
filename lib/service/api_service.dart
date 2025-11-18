import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:kebunsalak_app/config/config.dart';
import 'package:kebunsalak_app/models/article.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final String? body;
  final Uri? url;

  ApiException({this.statusCode, required this.message, this.body, this.url});

  @override
  String toString() =>
      'ApiException(status: ${statusCode ?? '-'}, url: ${url ?? '-'}): $message'
      '${body != null ? '\nBODY: $body' : ''}';
}

class ApiService {
  /// GET /api/articles
  static Future<List<Article>> fetchArticles() async {
    final uri = Uri.parse('${Config.apiUrl}/api/articles');
    try {
      final res = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(res.body);
        final List list = data['data'] ?? data; // fallback jika bukan paginator
        return list.map((e) => Article.fromJson(e)).toList();
      } else {
        throw ApiException(
          statusCode: res.statusCode,
          message: 'Gagal memuat artikel',
          body: res.body,
          url: uri,
        );
      }
    } on TimeoutException catch (e) {
      throw ApiException(message: 'Timeout koneksi: ${e.message}', url: uri);
    } on SocketException catch (e) {
      throw ApiException(message: 'Koneksi gagal: ${e.message}', url: uri);
    } on FormatException catch (e) {
      throw ApiException(message: 'Format JSON tidak valid: ${e.message}', url: uri);
    }
  }

  /// GET /api/articles/{slug}
  // lib/service/api_service.dart
  static Future<Article> fetchDetail(String slug) async {
    final uri = Uri.parse('${Config.apiUrl}/api/articles/$slug');
    try {
      final res = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final Map<String, dynamic> root = json.decode(res.body);
        // ⬇️ Ambil objek inti dari "data" jika ada, kalau tidak pakai root
        final Map<String, dynamic> obj =
            (root['data'] is Map<String, dynamic>) ? root['data'] : root;

        return Article.fromJson(obj);
      } else {
        throw ApiException(
          statusCode: res.statusCode,
          message: 'Gagal memuat detail artikel',
          body: res.body,
          url: uri,
        );
      }
    } on TimeoutException catch (e) {
      throw ApiException(message: 'Timeout: ${e.message}', url: uri);
    } on SocketException catch (e) {
      throw ApiException(message: 'Koneksi gagal: ${e.message}', url: uri);
    } on FormatException catch (e) {
      throw ApiException(message: 'JSON tidak valid: ${e.message}', url: uri);
    }
  }
}
