import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ta_monitor/screens/profile/edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final User _currentUser;
  // Jadikan Future non-final agar bisa di-refresh
  late Future<DocumentSnapshot<Map<String, dynamic>>> _userDataFuture;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser!;
    _userDataFuture = _fetchUserData();
  }

  // Memisahkan logika fetch data
  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchUserData() {
    return FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).get();
  }

  // Logika untuk refresh data setelah edit
  void _refreshUserData() {
    setState(() {
      _userDataFuture = _fetchUserData();
    });
  }

  // Navigasi ke halaman edit dan menunggu hasilnya
  Future<void> _navigateToEditProfile() async {
    final bool? result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const EditProfilePage()),
    );

    // Jika pengguna menekan "Save" di halaman edit, result akan true
    if (result == true) {
      _refreshUserData();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _userDataFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("User data not found."));
          }

          final userData = snapshot.data!.data()!;
          final fullName = userData['fullName'] as String? ?? 'N/A';
          final email = userData['email'] as String? ?? 'N/A';
          final role = userData['role'] as String? ?? 'N/A';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                            style: TextStyle(fontSize: 40, color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        Text(email, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(role, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          backgroundColor: Colors.blue.shade700,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildProfileOption(
                  context,
                  icon: Icons.edit_outlined,
                  title: 'Edit Profile',
                  onTap: _navigateToEditProfile, // Sambungkan ke fungsi navigasi
                  enabled: true, // AKTIFKAN TOMBOL
                ),
                _buildProfileOption(
                  context,
                  icon: Icons.lock_reset_outlined,
                  title: 'Change Password',
                  onTap: () { /* TODO: Implement Change Password */ },
                  enabled: false,
                ),
                const SizedBox(height: 24),
                 ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileOption(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap, bool enabled = true}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue.shade700),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: enabled ? const Icon(Icons.chevron_right) : null,
        onTap: enabled ? onTap : null,
        enabled: enabled,
      ),
    );
  }
}
