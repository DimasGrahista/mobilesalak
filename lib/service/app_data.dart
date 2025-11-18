import 'package:shared_preferences/shared_preferences.dart';

class AppData {
  static const _keySelectedDate = 'selected_date';

  // Simpan tanggal (format string yyyy-MM-dd)
  static Future<void> saveSelectedDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedDate, date.toIso8601String());
  }

  // Ambil tanggal yang disimpan, jika tidak ada kembalikan null
  static Future<DateTime?> getSelectedDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString(_keySelectedDate);
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr);
  }

  // Hapus tanggal yang disimpan (kembali ke otomatis)
  static Future<void> clearSelectedDate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySelectedDate);
  }
}
