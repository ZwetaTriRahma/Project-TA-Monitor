import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ta_monitor/screens/dashboard/lecturer_student_files_page.dart';
import 'package:ta_monitor/screens/notifications/notifications_page.dart';
import 'package:ta_monitor/screens/profile/profile_page.dart';
import 'package:ta_monitor/screens/professional_screen.dart';
import 'package:ta_monitor/widgets/app_drawer.dart';


class LecturerDashboard extends StatefulWidget {
  const LecturerDashboard({super.key});

  @override
  State<LecturerDashboard> createState() => _LecturerDashboardState();
}

class _LecturerDashboardState extends State<LecturerDashboard> {
  late final User _currentUser;
  late final Future<DocumentSnapshot<Map<String, dynamic>>> _userDataFuture;

  // --- STATE BARU UNTUK PENCARIAN ---
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser!;
    _userDataFuture = FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).get();

    // Listener untuk memperbarui UI saat teks pencarian berubah
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _DashboardAppBar(userDataFuture: _userDataFuture, currentUser: _currentUser),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // --- UI BAR PENCARIAN BARU ---
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a student...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          // --- DAFTAR MAHASISWA YANG TERFILTER ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('lecturerId', isEqualTo: _currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const _EmptyStateView();
                }

                // LOGIKA FILTER PENCARIAN
                final filteredStudents = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final studentName = (data['fullName'] as String? ?? '').toLowerCase();
                  final query = _searchQuery.toLowerCase();
                  return studentName.contains(query);
                }).toList();

                if (filteredStudents.isEmpty) {
                  return const Center(child: Text('No students found for your search.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  itemCount: filteredStudents.length,
                  itemBuilder: (context, index) {
                    return _StudentCard(studentDoc: filteredStudents[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ProfessionalScreen()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Widget-widget lain tidak berubah...
class _DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _DashboardAppBar({required this.userDataFuture, required this.currentUser});

  final Future<DocumentSnapshot<Map<String, dynamic>>> userDataFuture;
  final User currentUser;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.blue.shade700,
      foregroundColor: Colors.white,
      title: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: userDataFuture,
        builder: (context, snapshot) {
          final userName = snapshot.data?.data()?['fullName'] as String? ?? 'Lecturer';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Lecturer Dashboard', style: TextStyle(fontSize: 14)),
              Text(userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          );
        },
      ),
      actions: [
         StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('notifications').where('recipientId', isEqualTo: currentUser.uid).where('isRead', isEqualTo: false).snapshots(),
          builder: (context, snapshot) {
            final count = snapshot.data?.docs.length ?? 0;
            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const NotificationsPage())),
                ),
                if(count > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(count.toString(), style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
                    ),
                  )
              ],
            );
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _EmptyStateView extends StatelessWidget {
  const _EmptyStateView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('No Assigned Students', style: TextStyle(fontSize: 18, color: Colors.grey)),
          Text('Students who select you as their lecturer will appear here', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center,),
        ],
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final QueryDocumentSnapshot studentDoc;

  const _StudentCard({required this.studentDoc});

  void _viewStudentFiles(BuildContext context) {
    final data = studentDoc.data() as Map<String, dynamic>;
    final studentName = data['fullName'] as String? ?? 'Student';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LecturerStudentFilesPage(studentId: studentDoc.id, studentName: studentName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = studentDoc.data() as Map<String, dynamic>;
    final fullName = data['fullName'] as String? ?? 'No name';
    final email = data['email'] as String? ?? 'No email';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : '?', style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
        ),
        title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(email),
        trailing: const Icon(Icons.chevron_right, color: Colors.blue),
        onTap: () => _viewStudentFiles(context),
      ),
    );
  }
}
