import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class SharedPreferencesHelper {
  // Fungsi untuk memeriksa apakah ada data tanggal yang disimpan di SharedPreferences
  static Future<void> checkSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    Set<String> allDates = prefs.getStringList('allDates')?.toSet() ?? {};  // Sesuaikan dengan key yang Anda gunakan
    
    if (allDates.isEmpty) {
      logger.d("Tidak ada data tanggal yang disimpan di SharedPreferences.");
    } else {
      logger.d("Data tanggal yang disimpan di SharedPreferences: $allDates");
    }
  }

  // Fungsi untuk menghapus data tanggal yang tidak relevan dari SharedPreferences
  static Future<void> clearSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Menghapus data tanggal yang sudah ada di SharedPreferences
    await prefs.remove('allDates'); // Sesuaikan dengan key yang Anda gunakan
    logger.d("Data tanggal di SharedPreferences telah dihapus.");
  }
}
