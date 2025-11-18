import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:kebunsalak_app/config/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kebunsalak_app/page/absensiPage/absensi_page.dart';
import 'package:kebunsalak_app/page/lapor_page.dart';
import 'package:kebunsalak_app/page/artikelPage/panduan_page.dart';
import 'package:kebunsalak_app/widgets/custom_bottom_navbar.dart';
import 'package:kebunsalak_app/page/settingPage/setting_page.dart';
import 'package:kebunsalak_app/page/home/riwayatabsen_page.dart';
import 'package:kebunsalak_app/page/raport.dart';
import 'package:kebunsalak_app/page/home/jadwal_page.dart';
import 'package:kebunsalak_app/page/home/riwayatlapor_page.dart';
import 'package:kebunsalak_app/page/home/cuti/cuti_page.dart';
import 'package:kebunsalak_app/page/home/cuti/riwayatcuti_page.dart';
import 'package:kebunsalak_app/page/home/panen_page.dart';
import 'package:kebunsalak_app/page/home/gaji.dart';



class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeContent(),
    const PanduanPage(), // Halaman 2
    const AbsensiPage(), // Halaman Absensi
    const LaporPage(), // Halaman 4
    const SettingPage(), // Halaman 5
  ];

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // bisa juga pakai warna sesuai header
      statusBarIconBrightness: Brightness.dark, // pakai dark jika background terang
    ));
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  String nama = '';
  String jabatan = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      nama = prefs.getString('nama') ?? 'User';
      jabatan = prefs.getString('jabatan') ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: const Color.fromARGB(255, 255, 255, 255),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF5E762F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Halo, $nama 👋',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      jabatan,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // 🔍 Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color.fromARGB(255, 181, 177, 177)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Placeholder konten tengah

            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: const Color.fromARGB(255, 190, 177, 177)),
                borderRadius: BorderRadius.circular(19),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset(
                  'assets/images/Home1.png', // Ganti dengan nama gambar kamu
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(child: Text('Gambar tidak ditemukan'));
                  },
                ),
              ),
            ),
            // Container(
            //   height: 150,
            //   width: double.infinity,
            //   decoration: BoxDecoration(
            //     color: Colors.white,
            //     border: Border.all(color: const Color.fromARGB(255, 190, 177, 177)),
            //     borderRadius: BorderRadius.circular(12),
            //   ),
            // ),
            const SizedBox(height: 24),

            //  Menu Grid
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildMenuItem(Icons.calendar_month, 'JADWAL', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const JadwalKegiatanPage()),
                  );
                }),
                _buildMenuItem(Icons.list, 'PANEN', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PanenPage()),
                  );
                }),
                _buildMenuItem(Icons.money, 'GAJI', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PenggajianPage()),
                  );
                }),
                _buildMenuItem(Icons.beach_access, 'CUTI', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PengajuanCutiPage()),
                  );
                }),
                _buildMenuItem(Icons.fingerprint, 'RIWAYAT\nABSEN', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RiwayatAbsensiPage()),
                  );
                }),
                _buildMenuItem(Icons.history, 'RIWAYAT\nLAPOR', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RiwayatLaporPage()),
                  );
                }),
                _buildMenuItem(Icons.book, 'RAPORT', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RaportPage()),
                  );
                }),
                _buildMenuItem(Icons.check_circle, 'CEK\nCUTI', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RiwayatCutiPage()),
                  );
                }),
              ],
            ),
            const SizedBox(height: 24),

            // 📘 Tutorial Perawatan
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color.fromARGB(255, 181, 177, 177)),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Color.fromARGB(255, 110, 147, 37)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tutorial Perawatan',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 4),
                        Text(
                          'Untuk mencegah hama pada kebun salak, lakukan pemangkasan rutin, jaga kebersihan lingkungan, dan aplikasikan insektisida organik secara berkala.',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    )
    );
  }

  Widget _buildMenuItem(IconData icon, String label, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF5E762F),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
