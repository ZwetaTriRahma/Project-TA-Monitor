
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ta_monitor/screens/home/mahasiswa_detail_page.dart';

class DosenDashboardPage extends StatefulWidget {
  const DosenDashboardPage({super.key});

  @override
  State<DosenDashboardPage> createState() => _DosenDashboardPageState();
}

class _DosenDashboardPageState extends State<DosenDashboardPage> {
  // Future untuk mendapatkan data dosen yang sedang login.
  late final Future<DocumentSnapshot> _lecturerDataFuture;
  late final User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    // Jika user ada, kita siapkan Future untuk mengambil datanya.
    if (_currentUser != null) {
      _lecturerDataFuture = FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
    } else {
      // Jika user null, buat Future yang langsung gagal.
      _lecturerDataFuture = Future.error('User is not logged in.');
    }
  }

  // Fungsi untuk membuat stream mahasiswa.
  Stream<QuerySnapshot> _getMahasiswaStream(String lecturerId) {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'Mahasiswa')
        .where('lecturerId', isEqualTo: lecturerId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lecturer Dashboard"),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _lecturerDataFuture,
        builder: (context, lecturerSnapshot) {
          if (lecturerSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (lecturerSnapshot.hasError) {
            return Center(child: Text('Gagal memuat profil Anda: ${lecturerSnapshot.error}'));
          }
          if (!lecturerSnapshot.hasData || !lecturerSnapshot.data!.exists) {
            return const Center(child: Text('Profil dosen tidak ditemukan di database.'));
          }

          // Jika Future berhasil, kita aman untuk memuat data mahasiswa.
          final lecturerId = lecturerSnapshot.data!.id;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Mahasiswa Bimbingan", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _getMahasiswaStream(lecturerId),
                  builder: (context, studentSnapshot) {
                    if (studentSnapshot.hasError) {
                      // Ini adalah error yang Anda lihat.
                      return Center(child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text('Error: Tidak dapat memuat daftar mahasiswa. Pastikan aturan keamanan Firebase Anda sudah benar.\n\nDetail: ${studentSnapshot.error}', textAlign: TextAlign.center),
                      ));
                    }
                    if (studentSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!studentSnapshot.hasData || studentSnapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('Belum ada mahasiswa bimbingan.'));
                    }

                    final mahasiswaDocs = studentSnapshot.data!.docs;

                    return ListView.builder(
                      itemCount: mahasiswaDocs.length,
                      itemBuilder: (context, index) {
                        final data = mahasiswaDocs[index].data() as Map<String, dynamic>;
                        final studentName = data['fullName'] ?? 'Nama tidak ada';
                        final studentEmail = data['email'] ?? 'Email tidak ada';
                        final studentId = mahasiswaDocs[index].id;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(child: Text(studentName.isNotEmpty ? studentName[0] : '-')),
                            title: Text(studentName),
                            subtitle: Text(studentEmail),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => MahasiswaDetailPage(studentId: studentId)),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

