import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'; // Import kIsWeb

class FirebaseApi {
  // Buat instance dari Firebase Messaging
  final _firebaseMessaging = FirebaseMessaging.instance;

  // Fungsi untuk menginisialisasi notifikasi
  Future<void> initNotifications() async {
    try {
      // Meminta izin dari pengguna (penting untuk iOS & Android 13+)
      NotificationSettings settings = await _firebaseMessaging.requestPermission();

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Mengambil FCM token untuk perangkat ini
        // Untuk web, tambahkan VAPID key jika diperlukan, namun standar bisa jalan.
        final fcmToken = await _firebaseMessaging.getToken();

        // Mencetak token ke konsol (berguna untuk testing)
        debugPrint('FCM Token: $fcmToken');

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
      } else {
        debugPrint('User declined or has not accepted notification permission (Status: ${settings.authorizationStatus})');
      }
    } catch (e) {
      // Menangani error jika izin diblokir secara permanen di browser
      debugPrint('Warning: Notification initialization failed or was blocked: $e');
    }
  }

  // Fungsi untuk menyimpan token ke Firestore
  Future<void> saveTokenToDatabase(String userId, {String? token}) async {
    final fcmToken = token ?? await _firebaseMessaging.getToken();
    if (fcmToken != null) {
      final tokensRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('tokens').doc(fcmToken);
      await tokensRef.set({
        'createdAt': FieldValue.serverTimestamp(),
        'platform': kIsWeb ? 'web' : 'mobile',
      });
    }
  }
}
