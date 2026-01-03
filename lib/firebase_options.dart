// ===== FILE INI DIISI OTOMATIS BERDASARKAN KONFIGURASI ANDA =====

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    // Konfigurasi untuk platform lain (Android/iOS) ditangani secara otomatis.
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        throw UnsupportedError(
          'DefaultFirebaseOptions for Android is not supported on this platform.',
        );
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions for iOS is not supported on this platform.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // --- KONFIGURASI WEB ANDA YANG SUDAH BENAR ---
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyBUXkTRUhJT5heLAmdybesfEPBlsuys9AI",
    authDomain: "device-streaming-1d7576c5.firebaseapp.com",
    projectId: "device-streaming-1d7576c5",
    storageBucket: "device-streaming-1d7576c5.appspot.com", // Menggunakan .appspot.com yang lebih umum
    messagingSenderId: "288451811584",
    appId: "1:288451811584:web:8e4f1f176c09ad6d86bbe5",
  );
}
