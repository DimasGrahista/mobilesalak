// -----------------------------------------------------------
//  raport_page.dart
// -----------------------------------------------------------
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kebunsalak_app/config/config.dart';   // ganti jika path berbeda
import 'package:logger/logger.dart';

var logger = Logger();

class RaportPage extends StatefulWidget {
  const RaportPage({super.key});

  @override
  State<RaportPage> createState() => _RaportPageState();
}

class _RaportPageState extends State<RaportPage> {
  // ---------------- DATA ----------------
  List<Map<String, dynamic>> absensiList = [];
  List<Map<String, dynamic>> cutiList = [];

  Map<String, List<Map<String, dynamic>>> absensiPerBulan = {};
  Map<String, List<Map<String, dynamic>>> cutiPerBulan = {};
  Map<String, int> totalCutiPerBulan = {};

  List<String> availableMonths = [];
  bool isLoading = true;

  // ---------------- LIFE-CYCLE ----------------
  @override
  void initState() {
    super.initState();
    fetchAbsensiAndCuti();
  }

  // ---------------- NETWORK ----------------
  Future<void> fetchAbsensiAndCuti() async {
    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final idKaryawan = prefs.getString('id_karyawan');

    try {
      final absensiResponse = await http.get(
        Uri.parse('${Config.apiUrl}/api/absensi/history/$idKaryawan'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final cutiResponse = await http.get(
        Uri.parse('${Config.apiUrl}/api/cuti/$idKaryawan'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      logger.d('Absensi status : ${absensiResponse.statusCode}');
      logger.d('Cuti    status : ${cutiResponse.statusCode}');

      if (absensiResponse.statusCode == 200 &&
          cutiResponse.statusCode == 200) {
        absensiList =
            List<Map<String, dynamic>>.from(jsonDecode(absensiResponse.body));
        cutiList =
            List<Map<String, dynamic>>.from(jsonDecode(cutiResponse.body));
        _separateDataByMonth(absensiList, cutiList);
      } else {
        _showError('Gagal memuat data absensi dan cuti');
      }
    } catch (e) {
      _showError('Terjadi kesalahan: $e');
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
    setState(() => isLoading = false);
  }

  // ---------------- PROCESSING ----------------
  void _separateDataByMonth(
      List<Map<String, dynamic>> absensiList,
      List<Map<String, dynamic>> cutiList) {
    final tempAbsensi = <String, List<Map<String, dynamic>>>{};
    final tempCuti = <String, List<Map<String, dynamic>>>{};

    for (var a in absensiList) {
      final m = _getMonthName(DateTime.parse(a['tanggal']).month);
      tempAbsensi.putIfAbsent(m, () => []).add(a);
    }
    for (var c in cutiList) {
      final m = _getMonthName(DateTime.parse(c['tanggal_mulai']).month);
      tempCuti.putIfAbsent(m, () => []).add(c);
    }

    final combined = <String, List<Map<String, dynamic>>>{};
    tempAbsensi.forEach((k, v) => combined.putIfAbsent(k, () => []).addAll(v));
    tempCuti.forEach((k, v) => combined.putIfAbsent(k, () => []).addAll(v));

    setState(() {
      absensiPerBulan = combined;
      cutiPerBulan = tempCuti;
      availableMonths = _getAvailableMonths(absensiPerBulan, cutiPerBulan);
      _calculateTotalCutiPerBulan(tempCuti);
      isLoading = false;
    });
  }

  // Urutkan nama bulan dari terbaru → terlama
  List<String> _getAvailableMonths(
    Map<String, List<Map<String, dynamic>>> absensiPerBulan,
    Map<String, List<Map<String, dynamic>>> cutiPerBulan,
  ) {
    final Set<String> months = {
      ...absensiPerBulan.keys,
      ...cutiPerBulan.keys,
    };

    const ordered = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    final list = months.toList()
      ..sort((a, b) => ordered.indexOf(b).compareTo(ordered.indexOf(a)));

    return list; // [Desember, November, …]
  }

  void _calculateTotalCutiPerBulan(
      Map<String, List<Map<String, dynamic>>> cutiPerBulan) {
    final total = <String, int>{};

    cutiPerBulan.forEach((month, list) {
      int days = 0;
      for (var c in list) {
        if (c['status_validasi'] != 'Approved') continue;
        final s = DateTime.parse(c['tanggal_mulai']);
        final e = DateTime.parse(c['tanggal_akhir']);
        days += e.difference(s).inDays + 1;
      }
      total[month] = days;
    });

    totalCutiPerBulan = total;
  }

  // ---------------- UI HELPERS ----------------
  String _getMonthName(int n) => const [
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember'
      ][n - 1];

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F4ED),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Raport', style: TextStyle(color: Colors.black)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: availableMonths.length,
                itemBuilder: (_, i) => _buildRaportCard(availableMonths[i]),
              ),
      ),
    );
  }

  // ---------------- CARD ----------------
  Widget _buildRaportCard(String month) {
    if (!absensiPerBulan.containsKey(month) &&
        !cutiPerBulan.containsKey(month)) {
      return const SizedBox.shrink();
    }

    final combined = [
      ...?absensiPerBulan[month],
      ...?cutiPerBulan[month],
    ];

    final k = calculateKedisiplinan(
        combined, cutiPerBulan[month] ?? <Map<String, dynamic>>[]);
    final totalCuti = totalCutiPerBulan[month] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Text(month,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold))),
            const SizedBox(height: 12),

            _statRow(Icons.check_circle, 'Hadir', k['kehadiran']),
            _statRow(Icons.schedule, 'Terlambat', k['keterlambatan'],
                color: Colors.orange),
            _statRow(Icons.exit_to_app, 'Pulang Cepat', k['pulangLebihAwal'],
                color: Colors.orange),
            _statRow(Icons.beach_access, 'Total Cuti', totalCuti,
                color: Colors.teal),
            _statRow(Icons.help_outline, 'Tanpa Keterangan',
                k['tanpaKeterangan'],
                color: Colors.red),

            const Divider(height: 24),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Cetak'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFF5E762F),
                  foregroundColor: const Color.fromARGB(255, 253, 253, 253),
                  side: const BorderSide(color: Color(0xFF5E762F)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {}, // TODO: aksi print
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(IconData icon, String label, int? value,
      {Color color = Colors.green}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text((value ?? 0).toString(),
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ---------------- LOGIC KE-DISIPLINAN ----------------
  Map<String, int> calculateKedisiplinan(
      List<Map<String, dynamic>> absensiList,
      List<Map<String, dynamic>> cutiList) {
    int hadir = 0, telat = 0, pulangAwal = 0, tanpaKet = 0;
    final inDays = <String>{}, outDays = <String>{};

    const scheduledHour = 8, scheduledMinute = 0;

    for (var a in absensiList) {
      final status = a['status'] ?? '';
      final tanggal = a['tanggal'] ?? '';
      final waktu = a['waktu'] ?? '';

      try {
        final dt = DateTime.parse('$tanggal $waktu');
        if (status == 'in') {
          inDays.add(tanggal);
          if (dt.hour > scheduledHour ||
              (dt.hour == scheduledHour && dt.minute > scheduledMinute)) {
            telat++;
          }
        } else if (status == 'out') {
          outDays.add(tanggal);
          if (dt.isBefore(DateTime(dt.year, dt.month, dt.day, 17, 0))) {
            pulangAwal++;
          }
        }
      } catch (_) {}
    }

    // hitung tanpa keterangan (weekday, bukan cuti, tidak ada in/out)
    final approvedRanges = <String>{};
    for (var c in cutiList.where((e) => e['status_validasi'] == 'Approved')) {
      final s = DateTime.parse(c['tanggal_mulai']);
      final e = DateTime.parse(c['tanggal_akhir']);
      for (var d = s; !d.isAfter(e); d = d.add(const Duration(days: 1))) {
        approvedRanges.add(d.toIso8601String().split('T').first);
      }
    }

    final allDates = {...inDays, ...outDays}.toList()..sort();
    if (allDates.isNotEmpty) {
      final firstDay =
          DateTime.parse('${allDates.first} 00:00:00');
      final lastAbs =
          DateTime.parse('${allDates.last} 00:00:00');

      for (var d = firstDay;
          d.isBefore(lastAbs);
          d = d.add(const Duration(days: 1))) {
        final t = d.toIso8601String().split('T').first;
        if (d.weekday <= 5 && // Senin–Jumat
            !inDays.contains(t) &&
            !outDays.contains(t) &&
            !approvedRanges.contains(t)) {
          tanpaKet++;
        }
      }
    }

    hadir = inDays.intersection(outDays).length;

    return {
      'kehadiran': hadir,
      'keterlambatan': telat,
      'pulangLebihAwal': pulangAwal,
      'tanpaKeterangan': tanpaKet,
    };
  }
}