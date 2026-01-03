import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Drawer();
    }

    return Drawer(
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final role = userData['role'] as String?;

          return ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              UserAccountsDrawerHeader(
                accountName: Text(userData['fullName'] ?? 'User'),
                accountEmail: Text(userData['email'] ?? 'No email'),
                currentAccountPicture: CircleAvatar(
                  backgroundImage: NetworkImage(userData['profileImageUrl'] ?? 'https://i.pravatar.cc/150?u=a042581f4e29026704d'),
                ),
              ),
              if (role == 'Dosen') ...[
                _buildLecturerMenu(context, user.uid),
              ] else if (role == 'Mahasiswa') ...[
                _buildStudentMenu(context, user.uid),
              ],
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () => FirebaseAuth.instance.signOut(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLecturerMenu(BuildContext context, String lecturerId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('lecturerId', isEqualTo: lecturerId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ListTile(title: Text('Loading students...'));
        }

        final students = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('My Students', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (var studentDoc in students) ...[
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(studentDoc['fullName'] ?? 'Unknown Student'),
                onTap: () {},
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStudentMenu(BuildContext context, String studentId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('My Progress', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('files')
              .where('uploaderId', isEqualTo: studentId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const ListTile(title: Text('Loading...'));
            }

            final files = snapshot.data!.docs;
            final approvedCount = files.where((file) => file['status'] == 'Approved').length;
            final progress = files.isEmpty ? 0.0 : approvedCount / files.length;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text('$approvedCount of ${files.length} tasks approved'),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
