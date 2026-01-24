
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ta_monitor/screens/home/upload_file_page.dart';
import 'package:ta_monitor/widgets/app_drawer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      // This case should ideally be handled by the auth stream in main.dart
      return const Scaffold(body: Center(child: Text('Please log in.')));
    }

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('My Thesis Progress'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // [FIX] Menggunakan koleksi 'uploads' yang benar
        stream: FirebaseFirestore.instance
            .collection('uploads') 
            .where('userId', isEqualTo: user!.uid)
            .orderBy('uploadedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'You have not uploaded any files yet.\nPress the + button to upload your thesis file.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                ),
              ),
            );
          }

          final files = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(10.0),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final fileData = files[index].data() as Map<String, dynamic>;
              // [FIX] Menggunakan ID dokumen sebagai referensi unik
              final fileId = files[index].id;
              return _buildFileCard(context, fileId, fileData);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const UploadFilePage(),
          ));
        },
        icon: const Icon(Icons.add),
        label: const Text('Upload File'),
        tooltip: 'Upload a new thesis file',
      ),
    );
  }

  // --- [REFINED] Kartu file yang lebih informatif ---
  Widget _buildFileCard(BuildContext context, String fileId, Map<String, dynamic> fileData) {
    final status = fileData['status'] as String? ?? 'Pending';
    final feedback = fileData['feedback'] as String?;
    final fileName = fileData['fileName'] as String? ?? 'No Name';
    final downloadUrl = fileData['downloadUrl'] as String?;
    final Timestamp? timestamp = fileData['uploadedAt'] as Timestamp?;
    final date = timestamp != null ? DateFormat('d MMMM y, HH:mm').format(timestamp.toDate()) : 'No date';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getIconForFileName(fileName), color: Theme.of(context).primaryColor, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(fileName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ),
                if (downloadUrl != null)
                  IconButton(
                    icon: const Icon(Icons.download_for_offline_outlined, color: Colors.blueGrey),
                    tooltip: 'Download File',
                    onPressed: () async {
                       try {
                          final uri = Uri.parse(downloadUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } else {
                             if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch URL')));
                          }
                        } catch (e) {
                           if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid URL: $e')));
                        }
                    },
                  ),
              ],
            ),
            const Divider(height: 15),
            Text('Uploaded on: $date'),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Status: ', style: Theme.of(context).textTheme.bodyMedium),
                Chip(
                  label: Text(status),
                  backgroundColor: _getColorForStatus(status),
                  labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (feedback != null && feedback.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[100]!)
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text('Lecturer Feedback:', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87)),
                       const SizedBox(height: 4),
                       Text(feedback, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForFileName(String? fileName) {
    if (fileName == null) return Icons.article_outlined;
    if (fileName.toLowerCase().endsWith('.pdf')) return Icons.picture_as_pdf;
    if (fileName.toLowerCase().endsWith('.doc') || fileName.toLowerCase().endsWith('.docx')) return Icons.description;
    return Icons.article_outlined;
  }

  Color _getColorForStatus(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green.shade600;
      case 'Revision':
        return Colors.orange.shade700;
      case 'Rejected':
        return Colors.red.shade600;
      default: // Pending
        return Colors.blueGrey.shade500;
    }
  }
}
