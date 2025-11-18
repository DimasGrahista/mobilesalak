// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:http/http.dart' as http;  // Impor http
// import 'dart:convert';  // Impor dart:convert untuk jsonEncode

// class FirebaseService {
//   FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

//   // Ambil token FCM
//   Future<String?> getFCMToken() async {
//     try {
//       String? fcmToken = await _firebaseMessaging.getToken();
//       if (fcmToken != null) {
//         // Kirim token ke server Laravel untuk disimpan di database
//         await sendFCMTokenToBackend(fcmToken);
//         return fcmToken;
//       } else {
//         print("FCM token tidak ditemukan");
//         return null;
//       }
//     } catch (e) {
//       print("Error mendapatkan FCM token: $e");
//       return null;
//     }
//   }

//   // Kirim token ke server Laravel
//   Future<void> sendFCMTokenToBackend(String fcmToken) async {
//     // Gantilah URL API sesuai dengan endpoint backend Laravel Anda
//     final String apiUrl = "https://your-backend-url.com/api/store-fcm-token";
    
//     // Kirim token ke backend Laravel menggunakan HTTP request
//     try {
//       final response = await http.post(
//         Uri.parse(apiUrl),
//         headers: {
//           'Content-Type': 'application/json',
//         },
//         body: jsonEncode({
//           'fcm_token': fcmToken,
//           'id_karyawan': 1, // Gantilah dengan ID Karyawan yang sesuai
//         }),
//       );

//       if (response.statusCode == 200) {
//         print("FCM token berhasil dikirim ke server");
//       } else {
//         print("Gagal mengirim FCM token ke server");
//       }
//     } catch (e) {
//       print("Error mengirim FCM token ke server: $e");
//     }
//   }
// }
