import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ta_monitor/auth_wrapper.dart';
import 'package:ta_monitor/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Jika inisialisasi Firebase gagal, kita bisa menampilkannya di console.
    print('Firebase initialization failed: $e');
  }

  runApp(const TAMonitorApp());
}

class TAMonitorApp extends StatelessWidget {
  const TAMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TA Monitor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}
