import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kebunsalak_app/page/login_page.dart';
import 'package:kebunsalak_app/service/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Tambahkan baris ini
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kebun Salak App',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const LoginPage(),
    );
  }
}
