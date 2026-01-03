import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:ta_monitor/screens/details/file_details_page.dart';
import 'package:ta_monitor/screens/notifications/notifications_page.dart';
import 'package:ta_monitor/screens/profile/profile_page.dart';
import 'package:ta_monitor/widgets/app_drawer.dart';


class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  late final User _currentUser;
  late final Future<DocumentSnapshot<Map<String, dynamic>>> _userDataFuture;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser!;
    _userDataFuture = FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).get();
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text));
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a file...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('files')
                  .where('uploaderId', isEqualTo: _currentUser.uid)
                  .orderBy('uploadedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const _EmptyStateView();
                }

                final filteredFiles = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final fileName = (data['fileName'] as String? ?? '').toLowerCase();
                  final query = _searchQuery.toLowerCase();
                  return fileName.contains(query);
                }).toList();

                if (filteredFiles.isEmpty) {
                  return const Center(child: Text('No files found for your search.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12.0),
                  itemCount: filteredFiles.length,
                  itemBuilder: (context, index) => _FileCard(fileDoc: filteredFiles[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _UploadButton(currentUser: _currentUser, userDataFuture: _userDataFuture),
    );
  }
}

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
          final userName = snapshot.data?.data()?['fullName'] as String? ?? 'Student';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Student Dashboard', style: TextStyle(fontSize: 14)),
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

class _UploadButton extends StatefulWidget {
  const _UploadButton({required this.currentUser, required this.userDataFuture});

  final User currentUser;
  final Future<DocumentSnapshot<Map<String, dynamic>>> userDataFuture;

  @override
  State<_UploadButton> createState() => _UploadButtonState();
}

class _UploadButtonState extends State<_UploadButton> {
  bool _isUploading = false;

  Future<void> _uploadFile() async {
    setState(() => _isUploading = true);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx']);

      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _isUploading = false);
        return;
      }

      final pickedFile = result.files.single;
      final fileName = pickedFile.name;
      final ref = FirebaseStorage.instance.ref().child('uploads/${widget.currentUser.uid}/$fileName');

      if (kIsWeb) {
        if (pickedFile.bytes == null) {
          throw Exception("File bytes are null on web");
        }
        await ref.putData(pickedFile.bytes!);
      } else {
        if (pickedFile.path == null) {
          throw Exception("File path is null on mobile");
        }
        final file = File(pickedFile.path!);
        await ref.putFile(file);
      }

      final downloadUrl = await ref.getDownloadURL();

      // --- PERUBAHAN MODEL DATA ---
      await FirebaseFirestore.instance.collection('files').add({
        'uploaderId': widget.currentUser.uid,
        'fileName': fileName,
        'downloadUrl': downloadUrl,
        'uploadedAt': Timestamp.now(),
        'status': 'Pending Review', // Status default baru
      });
      // --- AKHIR PERUBAHAN ---

      final userData = await widget.userDataFuture;
      final studentName = userData.data()?['fullName'] as String? ?? 'A student';
      final lecturerId = userData.data()?['lecturerId'] as String?;

      if(lecturerId != null) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'recipientId': lecturerId,
          'title': 'New File Uploaded',
          'body': '$studentName has uploaded a new file: $fileName',
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File uploaded successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload file: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: _isUploading ? null : _uploadFile,
      tooltip: 'Upload File',
      icon: _isUploading ? const SizedBox.shrink() : const Icon(Icons.upload_file),
      label: _isUploading ? const CircularProgressIndicator(color: Colors.white) : const Text('Upload File'),
      backgroundColor: Colors.blue.shade700,
      foregroundColor: Colors.white,
    );
  }
}


class _EmptyStateView extends StatelessWidget {
  const _EmptyStateView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('No files uploaded yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
          Text('Press the + button to upload your first file', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  final QueryDocumentSnapshot fileDoc;

  const _FileCard({required this.fileDoc});

  Future<void> _showDeleteConfirmationDialog(BuildContext context, String? downloadUrl) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to permanently delete this file? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Delete'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  if (downloadUrl != null) {
                    await FirebaseStorage.instance.refFromURL(downloadUrl).delete();
                  }
                  await fileDoc.reference.delete();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('File deleted successfully'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete file: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  // --- LOGIKA BARU UNTUK UI STATUS ---
  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case 'Approved':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        icon = Icons.check_circle;
        break;
      case 'Revisions Needed':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        icon = Icons.edit;
        break;
      default: // Pending Review
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        icon = Icons.hourglass_top;
        break;
    }

    return Chip(
      avatar: Icon(icon, color: textColor, size: 16),
      label: Text(status),
      backgroundColor: backgroundColor,
      labelStyle: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      side: BorderSide.none,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = fileDoc.data() as Map<String, dynamic>;
    final fileName = data['fileName'] as String? ?? 'No name';
    final downloadUrl = data['downloadUrl'] as String?;
    final status = data['status'] as String? ?? 'Pending Review'; // Ambil data status

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16.0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => FileDetailsPage(fileId: fileDoc.id))),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(status), // Gunakan widget status baru
                ],
              ),
              const Divider(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete File'),
                  onPressed: () => _showDeleteConfirmationDialog(context, downloadUrl),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
