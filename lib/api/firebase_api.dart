import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FirebaseApi {
  // Buat instance dari Firebase Messaging
  final _firebaseMessaging = FirebaseMessaging.instance;

  // Fungsi untuk menginisialisasi notifikasi
  Future<void> initNotifications() async {
    // Meminta izin dari pengguna (penting untuk iOS & Android 13+)
    await _firebaseMessaging.requestPermission();

    // Mengambil FCM token untuk perangkat ini
    final fcmToken = await _firebaseMessaging.getToken();

    // Mencetak token ke konsol (berguna untuk testing)
    print('FCM Token: $fcmToken');

    // Menyimpan token ke database jika pengguna sudah login
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await saveTokenToDatabase(currentUser.uid);
    }

    // Listener untuk memperbarui token jika berubah
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      if (currentUser != null) {
        await saveTokenToDatabase(currentUser.uid, token: newToken);
      }
    });
  }

  // Fungsi untuk menyimpan token ke Firestore
  Future<void> saveTokenToDatabase(String userId, {String? token}) async {
    final fcmToken = token ?? await _firebaseMessaging.getToken();
    if (fcmToken != null) {
      final tokensRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('tokens').doc(fcmToken);
      await tokensRef.set({
        'createdAt': FieldValue.serverTimestamp(),
        'platform': 'mobile', // Anda bisa kembangkan ini nanti untuk web
      });
    }
  }
}
