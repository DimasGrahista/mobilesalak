import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kebunsalak_app/page/settingPage/updateprofile_page.dart';
import 'package:kebunsalak_app/page/login_page.dart';
import 'package:kebunsalak_app/service/theme_provider.dart';


class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'Indonesia';

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pengaturan"),
        backgroundColor: const Color(0xFF5E762F),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),

          // Profil
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Profil Saya"),
            subtitle: const Text("Lihat & ubah informasi akun"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UpdateProfilePage()),
              );
            },
          ),
          const Divider(),

          // Notifikasi
          SwitchListTile(
            title: const Text("Aktifkan Notifikasi"),
            value: _notificationsEnabled,
            onChanged: (val) {
              setState(() => _notificationsEnabled = val);
            },
            secondary: const Icon(Icons.notifications),
          ),

          // Mode Gelap
          SwitchListTile(
            title: const Text("Mode Gelap"),
            value: themeProvider.isDarkMode,
            onChanged: (val) {
              themeProvider.toggleTheme(val);
            },
            secondary: const Icon(Icons.dark_mode),
          ),

          // Bahasa
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text("Bahasa"),
            subtitle: Text(_selectedLanguage),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showLanguageDialog,
          ),

          const Divider(),

          // Kontak admin
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text("Hubungi Admin"),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Fitur kontak admin belum tersedia")),
              );
            },
          ),

          // Logout
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Keluar"),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Pilih Bahasa"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text("Indonesia"),
              value: "Indonesia",
              groupValue: _selectedLanguage,
              onChanged: (val) {
                setState(() => _selectedLanguage = val!);
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<String>(
              title: const Text("English"),
              value: "English",
              groupValue: _selectedLanguage,
              onChanged: (val) {
                setState(() => _selectedLanguage = val!);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }
}
