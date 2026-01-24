
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ta_monitor/screens/chat/chat_screen.dart';
import 'package:ta_monitor/services/chat_service.dart';
import 'package:url_launcher/url_launcher.dart';

class MahasiswaDetailPage extends StatefulWidget {
  final String studentId;

  const MahasiswaDetailPage({super.key, required this.studentId});

  @override
  State<MahasiswaDetailPage> createState() => _MahasiswaDetailPageState();
}

class _MahasiswaDetailPageState extends State<MahasiswaDetailPage> {
  late final Future<DocumentSnapshot> _studentFuture;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _studentFuture = FirebaseFirestore.instance.collection('users').doc(widget.studentId).get();
  }

  Stream<QuerySnapshot> _getUploadedFilesStream() {
    return FirebaseFirestore.instance
        .collection('uploads')
        .where('userId', isEqualTo: widget.studentId)
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }

  // [MODIFIED] Pass more context to the dialog
  void _showUpdateDialog(String fileId, String currentStatus, String currentFeedback, DateTime? currentDeadline, String fileName, String downloadUrl) {
    showDialog(
      context: context,
      builder: (context) => _UpdateStatusDialog(
        fileId: fileId,
        currentStatus: currentStatus,
        currentFeedback: currentFeedback,
        currentDeadline: currentDeadline,
        studentId: widget.studentId,
        fileName: fileName,
        downloadUrl: downloadUrl,
      ),
    );
  }

  void _startChat() async {
    if (_currentUser == null) return;
    showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()), barrierDismissible: false);
    try {
      final chatService = ChatService();
      final chatRoom = await chatService.getOrCreateChatRoom(_currentUser!.uid, widget.studentId);
      Navigator.pop(context);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => ChatScreen(chatRoom: chatRoom, currentUserId: _currentUser!.uid),
      ));
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to open chat: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _studentFuture,
      builder: (context, studentSnapshot) {
        if (studentSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        if (studentSnapshot.hasError || !studentSnapshot.hasData || !studentSnapshot.data!.exists) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Gagal memuat data mahasiswa.')));
        }

        final studentData = studentSnapshot.data!.data() as Map<String, dynamic>;
        final studentName = studentData['fullName'] ?? 'Tanpa Nama';

        return Scaffold(
          appBar: AppBar(
            title: Text(studentName),
            actions: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                tooltip: 'Chat with $studentName',
                onPressed: _startChat,
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Detail Mahasiswa:', style: Theme.of(context).textTheme.titleMedium),
                    Text(studentName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    Text('NIM: ${studentData['nim_or_nidn'] ?? '-'}'),
                    const Divider(height: 32),
                    Text('File Terunggah:', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _getUploadedFilesStream(),
                  builder: (context, fileSnapshot) {
                    if (fileSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!fileSnapshot.hasData || fileSnapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('Mahasiswa ini belum mengunggah file.'));
                    }

                    final files = fileSnapshot.data!.docs;
                    return ListView.builder(
                      itemCount: files.length,
                      itemBuilder: (context, index) {
                        final fileDoc = files[index];
                        final fileData = fileDoc.data() as Map<String, dynamic>;
                        final Timestamp timestamp = fileData['uploadedAt'] ?? Timestamp.now();
                        final formattedDate = DateFormat('d MMMM y, HH:mm').format(timestamp.toDate());
                        final status = fileData['status'] ?? 'Pending';
                        final feedback = fileData['feedback'] as String? ?? '';
                        // [NEW] Get deadline from data
                        final deadline = (fileData['revisionDeadline'] as Timestamp?)?.toDate();

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: ListTile(
                            leading: const Icon(Icons.description, size: 40),
                            title: Text(fileData['fileName'] ?? 'N/A'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Diunggah: $formattedDate'),
                                Text('Status: $status', style: const TextStyle(fontWeight: FontWeight.bold)),
                                if (feedback.isNotEmpty) Text('Feedback: $feedback', style: const TextStyle(color: Colors.blue, fontStyle: FontStyle.italic)),
                                // [NEW] Display deadline if it exists
                                if (deadline != null) Text('Deadline: ${DateFormat('d MMMM y').format(deadline)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.edit_note),
                            onTap: () => _showUpdateDialog(fileDoc.id, status, feedback, deadline, fileData['fileName'] ?? 'N/A', fileData['downloadUrl'] ?? ''),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- [REFINED] Dialog now includes a deadline picker ---
class _UpdateStatusDialog extends StatefulWidget {
  final String fileId;
  final String currentStatus;
  final String currentFeedback;
  final DateTime? currentDeadline;
  final String studentId;
  final String fileName;
  final String downloadUrl;

  const _UpdateStatusDialog({
    required this.fileId,
    required this.currentStatus,
    required this.currentFeedback,
    this.currentDeadline,
    required this.studentId,
    required this.fileName,
    required this.downloadUrl,
  });

  @override
  State<_UpdateStatusDialog> createState() => _UpdateStatusDialogState();
}

class _UpdateStatusDialogState extends State<_UpdateStatusDialog> {
  late String _selectedStatus;
  late TextEditingController _feedbackController;
  DateTime? _selectedDeadline;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final List<String> _statuses = ['Approved', 'Revision', 'Rejected', 'Pending'];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.currentStatus;
    _feedbackController = TextEditingController(text: widget.currentFeedback);
    _selectedDeadline = widget.currentDeadline;
  }

  Future<void> _updateFileDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final dataToUpdate = {
        'status': _selectedStatus,
        'feedback': _feedbackController.text.trim(),
        // Add or remove the deadline based on status
        'revisionDeadline': _selectedStatus == 'Revision' ? _selectedDeadline : FieldValue.delete(),
      };

      await FirebaseFirestore.instance.collection('uploads').doc(widget.fileId).update(dataToUpdate);

      // Send notification to student
      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientId': widget.studentId,
        'title': 'File Status Updated',
        'message': 'Your file "${widget.fileName}" status has been updated to $_selectedStatus.',
        'createdAt': Timestamp.now(),
        'isRead': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil memperbarui status.'), backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memperbarui: $e'), backgroundColor: Colors.red));
      }
    } finally {
       if (mounted) {
          setState(() => _isLoading = false);
       }
    }
  }

  // [NEW] Function to show date picker
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDeadline) {
      setState(() {
        _selectedDeadline = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Status & Feedback'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedStatus = value);
                },
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _feedbackController,
                decoration: const InputDecoration(
                  labelText: 'Feedback (Opsional)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
              ),
              // [NEW] Conditionally show the deadline picker
              if (_selectedStatus == 'Revision') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedDeadline == null 
                          ? 'No deadline set' 
                          : 'Deadline: ${DateFormat('d MMM yyyy').format(_selectedDeadline!)}',
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _selectDate,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (widget.downloadUrl.isNotEmpty)
          TextButton(
            onPressed: () async {
              if (!await launchUrl(Uri.parse(widget.downloadUrl), mode: LaunchMode.externalApplication)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open file')));
              }
            },
            child: const Text('View File'),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateFileDetails,
          child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Simpan'),
        ),
      ],
    );
  }
}
