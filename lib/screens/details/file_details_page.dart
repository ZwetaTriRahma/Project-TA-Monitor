import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class FileDetailsPage extends StatefulWidget {
  final String fileId;

  const FileDetailsPage({super.key, required this.fileId});

  @override
  State<FileDetailsPage> createState() => _FileDetailsPageState();
}

class _FileDetailsPageState extends State<FileDetailsPage> {
  final _commentController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser!;
  late final DocumentReference<Map<String, dynamic>> _fileRef;
  late final CollectionReference _commentsRef;

  @override
  void initState() {
    super.initState();
    _fileRef = FirebaseFirestore.instance.collection('files').doc(widget.fileId);
    _commentsRef = _fileRef.collection('comments');
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).get();
    final senderName = userDoc.data()?['fullName'] ?? 'Unknown User';

    await _commentsRef.add({
      'text': commentText,
      'senderId': _currentUser.uid,
      'senderName': senderName,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Guidance Room'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _fileRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('File not found or has been deleted.'));
          }
          
          final fileData = snapshot.data!.data()!;

          return Column(
            children: [
              _FileInfoSection(fileData: fileData, fileRef: _fileRef, currentUser: _currentUser),
              const Divider(height: 1),
              Expanded(
                child: _CommentsList(commentsRef: _commentsRef, currentUser: _currentUser),
              ),
              _CommentInputField(commentController: _commentController, onPost: _postComment),
            ],
          );
        },
      ),
    );
  }
}

// --- WIDGET-WIDGET BAGIAN HALAMAN ---

class _FileInfoSection extends StatelessWidget {
  final Map<String, dynamic> fileData;
  final DocumentReference<Map<String, dynamic>> fileRef;
  final User currentUser;

  const _FileInfoSection({required this.fileData, required this.fileRef, required this.currentUser});

  Future<void> _launchURL(BuildContext context, String url) async {
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch file')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = fileData['fileName'] ?? 'No name';
    final downloadUrl = fileData['downloadUrl'] as String?;
    final status = fileData['status'] as String? ?? 'Pending Review';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, size: 40, color: Colors.blue.shade700),
              const SizedBox(width: 16),
              Expanded(child: Text(fileName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              if (downloadUrl != null) IconButton(icon: const Icon(Icons.open_in_new), onPressed: () => _launchURL(context, downloadUrl)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Status: ', style: TextStyle(color: Colors.grey)),
              _buildStatusChip(status),
            ],
          ),
          // Panel khusus Dosen
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance.collection('users').doc(fileData['uploaderId']).get(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) return const SizedBox.shrink();
              final studentData = userSnapshot.data!.data()!;
              final lecturerId = studentData['lecturerId'];
              // Tampilkan hanya jika pengguna saat ini adalah dosen dari mahasiswa ini
              if (currentUser.uid == lecturerId) {
                return _LecturerActionPanel(fileRef: fileRef, fileData: fileData);
              }
              return const SizedBox.shrink();
            },
          )
        ],
      ),
    );
  }

    Widget _buildStatusChip(String status) {
    Color backgroundColor; Color textColor; IconData icon;
    switch (status) {
      case 'Approved':
        backgroundColor = Colors.green.shade100; textColor = Colors.green.shade800; icon = Icons.check_circle;
        break;
      case 'Revisions Needed':
        backgroundColor = Colors.orange.shade100; textColor = Colors.orange.shade800; icon = Icons.edit;
        break;
      default: // Pending Review
        backgroundColor = Colors.blue.shade100; textColor = Colors.blue.shade800; icon = Icons.hourglass_top;
        break;
    }
    return Chip(avatar: Icon(icon, color: textColor, size: 16), label: Text(status), backgroundColor: backgroundColor, labelStyle: TextStyle(color: textColor, fontWeight: FontWeight.bold), side: BorderSide.none);
  }
}

class _LecturerActionPanel extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> fileRef;
  final Map<String, dynamic> fileData;

  const _LecturerActionPanel({required this.fileRef, required this.fileData});

  Future<void> _updateStatus(String newStatus) async {
    await fileRef.update({'status': newStatus});

    // Kirim notifikasi ke mahasiswa
    final studentId = fileData['uploaderId'];
    final fileName = fileData['fileName'] ?? 'your file';
    await FirebaseFirestore.instance.collection('notifications').add({
      'recipientId': studentId,
      'title': 'File Status Updated',
      'body': 'The status of your file \'$fileName\' has been updated to \'$newStatus\'.',
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lecturer Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton.icon(icon: const Icon(Icons.edit, color: Colors.orange), label: const Text('Revisions Needed'), onPressed: () => _updateStatus('Revisions Needed')),
              TextButton.icon(icon: const Icon(Icons.check, color: Colors.green), label: const Text('Approve'), onPressed: () => _updateStatus('Approved')),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentsList extends StatelessWidget {
  final CollectionReference commentsRef;
  final User currentUser;

  const _CommentsList({required this.commentsRef, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: commentsRef.orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No comments yet. Start the conversation!'));
        }
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) => _ChatBubble(data: snapshot.data!.docs[index].data() as Map<String, dynamic>, isMe: (snapshot.data!.docs[index].data() as Map<String, dynamic>)['senderId'] == currentUser.uid),
        );
      },
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMe;

  const _ChatBubble({required this.data, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final text = data['text'] ?? '';
    final senderName = data['senderName'] ?? '';
    final timestamp = data['timestamp'] as Timestamp?;
    final time = timestamp != null ? '${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}' : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Card(
        color: isMe ? Colors.blue.shade600 : Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(senderName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isMe ? Colors.white70 : Colors.blue.shade900)),
              const SizedBox(height: 4),
              Text(text, style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              Align(alignment: Alignment.bottomRight, child: Text(time, style: TextStyle(fontSize: 10, color: isMe ? Colors.white60 : Colors.black54))),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentInputField extends StatelessWidget {
  final TextEditingController commentController;
  final VoidCallback onPost;

  const _CommentInputField({required this.commentController, required this.onPost});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 8, top: 8, bottom: MediaQuery.of(context).viewInsets.bottom + 8),
        child: Row(
          children: [
            Expanded(child: TextField(controller: commentController, decoration: const InputDecoration(hintText: 'Type your message here...', border: InputBorder.none), maxLines: null)),
            IconButton(icon: const Icon(Icons.send, color: Colors.blueAccent), onPressed: onPost),
          ],
        ),
      ),
    );
  }
}
