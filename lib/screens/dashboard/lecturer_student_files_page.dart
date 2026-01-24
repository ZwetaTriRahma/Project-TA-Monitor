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
      appBar: AppBar(
        title: Text(studentName),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('uploads')
            .where('userId', isEqualTo: studentId)
            .orderBy('uploadedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'This student has not uploaded any files yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              )
            );
          }

          final files = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final fileDoc = files[index];
              final fileData = fileDoc.data() as Map<String, dynamic>;
              return _buildFileCard(context, fileDoc.id, fileData);
            },
          );
        },
      ),
    );
  }

  Widget _buildFileCard(BuildContext context, String fileId, Map<String, dynamic> fileData) {
    final status = fileData['status'] ?? 'Pending';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: ListTile(
        leading: Icon(_getIconForFileName(fileData['fileName'])),
        title: Text(fileData['title'] ?? 'No Title', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fileData['fileName'] ?? ''),
            const SizedBox(height: 4),
            Chip(
              label: Text(status),
              backgroundColor: _getColorForStatus(status),
              labelStyle: const TextStyle(color: Colors.white),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => FileDetailsPage(fileId: fileId)),
        ),
      ),
    );
  }

  IconData _getIconForFileName(String? fileName) {
    if (fileName == null) return Icons.article;
    if (fileName.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (fileName.endsWith('.doc') || fileName.endsWith('.docx')) return Icons.description;
    return Icons.article;
  }

  Color _getColorForStatus(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Revision':
        return Colors.orange;
      case 'Rejected':
        return Colors.red;
      default: // Pending, In Review
        return Colors.blueGrey;
    }
  }
}
