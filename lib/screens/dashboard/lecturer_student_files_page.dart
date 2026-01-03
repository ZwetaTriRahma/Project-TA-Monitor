import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ta_monitor/screens/details/file_details_page.dart';

class LecturerStudentFilesPage extends StatelessWidget {
  final String studentId;
  final String studentName;

  const LecturerStudentFilesPage({super.key, required this.studentId, required this.studentName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(studentName),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('files')
            .where('uploaderId', isEqualTo: studentId)
            .orderBy('uploadedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('This student has not uploaded any files yet.'));
          }

          final files = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final fileDoc = files[index];
              final fileData = fileDoc.data() as Map<String, dynamic>;
              final fileName = fileData['fileName'] as String? ?? 'No name';

              return Card(
                margin: const EdgeInsets.only(bottom: 12.0),
                child: ListTile(
                  leading: const Icon(Icons.description),
                  title: Text(fileName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => FileDetailsPage(fileId: fileDoc.id)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
