// ===== KODE DIPERBAIKI UNTUK MENGATASI LAYAR PUTIH & LOGIN LOOP =====
// Semua sisa kode notifikasi yang menyebabkan crash telah dihapus.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// import 'package:ta_monitor/api/firebase_api.dart'; // DIHAPUS
import 'package:ta_monitor/screens/auth/login_page.dart';
import 'package:ta_monitor/screens/dashboard/lecturer_dashboard.dart';
import 'package:ta_monitor/screens/dashboard/student_dashboard.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Selama koneksi masih aktif mencari status user
        if (snapshot.connectionState == ConnectionState.active) {
          final User? user = snapshot.data;
          // Jika tidak ada user, tampilkan halaman login
          if (user == null) {
            return const LoginPage();
          }
          // Jika ada user, cek perannya di database
          // FirebaseApi().saveTokenToDatabase(user.uid); // DIHAPUS
          return RoleBasedRedirect(userId: user.uid);
        }
        // Selama loading, tampilkan spinner
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

class RoleBasedRedirect extends StatelessWidget {
  final String userId;

  const RoleBasedRedirect({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        // Jika proses pengambilan data selesai
        if (snapshot.connectionState == ConnectionState.done) {
          // Jika data user ada dan rolenya jelas
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final role = data['role'];

            if (role == 'Mahasiswa') {
              return const StudentDashboard();
            } else if (role == 'Dosen') {
              return const LecturerDashboard();
            }
          }
          // JIKA DATA USER TIDAK DITEMUKAN ATAU TIDAK PUNYA PERAN
          // (misal: pengguna Google baru yang belum melengkapi profil)
          // Ini adalah penyebab "login loop". Kita akan tampilkan halaman error.
          return const _AuthErrorScreen();
        }
        // Selama loading, tampilkan spinner
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

// Halaman error yang aman untuk mencegah loop
class _AuthErrorScreen extends StatelessWidget {
  const _AuthErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              const Text(
                'Authentication Error',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your user data could not be found. This can happen if you are a new user who signed in with Google but did not complete the profile registration.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text('Return to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
