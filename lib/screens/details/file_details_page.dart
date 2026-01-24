import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    _fileRef = FirebaseFirestore.instance.collection('uploads').doc(widget.fileId);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    // ... (logic is unchanged)
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Submission Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              // Show history logic
            },
            tooltip: 'Revision History',
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _fileRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('File not found.'));
          }
          
          final fileData = snapshot.data!.data()!;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _FileInfoSection(fileData: fileData, fileRef: _fileRef),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Discussion Thread',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            _CommentsList(commentsRef: _fileRef.collection('comments'), currentUser: _currentUser),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _CommentInputField(commentController: _commentController, onPost: _postComment),
            ],
          );
        },
      ),
      bottomSheet: _CommentInputField(commentController: _commentController, onPost: _postComment),
    );
  }
}

// --- WIDGETS ---

class _FileInfoSection extends StatefulWidget {
  final Map<String, dynamic> fileData;
  final DocumentReference fileRef;

  const _FileInfoSection({required this.fileData, required this.fileRef});

  @override
  State<_FileInfoSection> createState() => _FileInfoSectionState();
}

class _FileInfoSectionState extends State<_FileInfoSection> {
  bool _isUploadingRevision = false;

  Future<void> _launchURL(BuildContext context, String url) async {
    debugPrint('Launching URL: $url');
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open file')));
    }
  }

   Future<void> _uploadRevision() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result == null) return;

    setState(() => _isUploadingRevision = true);

    try {
      final pickedFile = result.files.single;

      // Cloudinary upload logic
      final String cloudinaryCloudName = 'dl7kvbaao';
      final String cloudinaryApiKey = '526219655212682';
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudinaryCloudName/raw/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['api_key'] = cloudinaryApiKey
        ..fields['upload_preset'] = 'default';

      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes('file', pickedFile.bytes!, filename: pickedFile.name));
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', pickedFile.path!));
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseString = await response.stream.bytesToString();
        final jsonMap = jsonDecode(responseString);
        debugPrint('Response JSON: $jsonMap');
        if (jsonMap.containsKey('error')) {
          throw Exception('Cloudinary error: ${jsonMap['error']['message']}');
        }
        final newDownloadUrl = jsonMap['secure_url'];
        debugPrint('New Download URL: $newDownloadUrl');

        // Create a NEW document to preserve history
        await FirebaseFirestore.instance.collection('uploads').add({
          'userId': widget.fileData['userId'],
          'downloadUrl': newDownloadUrl,
          'fileName': pickedFile.name,
          'title': '${widget.fileData['title']} (Revision)',
          'status': 'Pending', // New submission starts as pending
          'uploadedAt': Timestamp.now(),
          'parentId': widget.fileRef.id, // Link to previous version
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Revision submitted successfully!'), backgroundColor: Colors.green),
          );
          Navigator.pop(context); // Go back after revision
        }
      } else {
        throw Exception('Failed to upload revision to Cloudinary.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingRevision = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser!;
    final status = widget.fileData['status'] as String? ?? 'Pending';
    final feedback = widget.fileData['feedback'] as String?;
    final feedbackImageUrl = widget.fileData['feedbackImageUrl'] as String?;
    final isStudentUploader = currentUser.uid == widget.fileData['userId'];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.description_outlined, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.fileData['title'] ?? 'No Title',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              widget.fileData['fileName'] ?? 'Unknown File',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      if (widget.fileData['downloadUrl'] != null)
                        IconButton.filledTonal(
                          icon: const Icon(Icons.download),
                          onPressed: () => _launchURL(context, widget.fileData['downloadUrl']),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatusChip(context, status),
                      Text(
                        'Last update: ${DateFormat('d MMM yyyy').format((widget.fileData['uploadedAt'] as Timestamp).toDate())}',
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (feedback != null && feedback.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Lecturer\'s Feedback',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feedback,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  if (feedbackImageUrl != null) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => Dialog(child: Image.network(feedbackImageUrl)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(feedbackImageUrl, height: 120, fit: BoxFit.cover),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Actions for Student or Lecturer
          if (isStudentUploader && status == 'Revision')
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: _isUploadingRevision 
                ? const Center(child: CircularProgressIndicator()) 
                : ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file), 
                    label: const Text('UPLOAD REVISION'), 
                    onPressed: _uploadRevision, 
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
            )
          else
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(widget.fileData['userId']).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) return const SizedBox.shrink();
                final studentData = userSnapshot.data?.data() as Map<String, dynamic>?;
                if (studentData != null && currentUser.uid == studentData['lecturerId']) {
                  return _LecturerActionPanel(fileRef: widget.fileRef, fileData: widget.fileData);
                }
                return const SizedBox.shrink();
              },
            )
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'Approved':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'Revision':
        color = Colors.orange;
        icon = Icons.edit_notifications;
        break;
      case 'Rejected':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.blue;
        icon = Icons.hourglass_top;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ... (Rest of the widgets are the same)
class _LecturerActionPanel extends StatefulWidget {
  final DocumentReference fileRef;
  final Map<String, dynamic> fileData;

  const _LecturerActionPanel({required this.fileRef, required this.fileData});

  @override
  State<_LecturerActionPanel> createState() => _LecturerActionPanelState();
}

class _LecturerActionPanelState extends State<_LecturerActionPanel> {
  late final TextEditingController _feedbackController;
  XFile? _pickedImage;
  bool _isUploading = false;

  // Cloudinary Credentials
  final String _cloudinaryCloudName = 'dl7kvbaao';
  final String _cloudinaryApiKey = '526219655212682';
  final String _cloudinaryApiSecret = '0qXkgmo5hOPa32KxLBQ2rWc6s4U';

  @override
  void initState() {
    super.initState();
    _feedbackController = TextEditingController(text: widget.fileData['feedback']);
  }

  Future<void> _pickImage() async {
    final pickedImageFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedImageFile != null) {
      setState(() => _pickedImage = pickedImageFile);
    }
  }

  Future<String?> _uploadImageToCloudinary(XFile image) async {
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final signatureString = 'timestamp=$timestamp$_cloudinaryApiSecret';
      final signatureBytes = utf8.encode(signatureString);
      final signature = sha1.convert(signatureBytes).toString();
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['api_key'] = _cloudinaryApiKey
        ..fields['timestamp'] = timestamp
        ..fields['signature'] = signature;
      final bytes = await image.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: image.name));
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseString = await response.stream.bytesToString();
        final jsonMap = jsonDecode(responseString);
        return jsonMap['secure_url'];
      }
      return null;
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUploading = true);
    try {
      String? feedbackImageUrl;
      if (_pickedImage != null) {
        feedbackImageUrl = await _uploadImageToCloudinary(_pickedImage!);
      }

      await widget.fileRef.update({
        'status': newStatus,
        'feedback': _feedbackController.text.trim(),
        'feedbackImageUrl': feedbackImageUrl, // Always update with new value (which can be null)
      });

      // [FIX] Clear the form after successful submission
      _feedbackController.clear();
      setState(() {
        _pickedImage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('File status updated to $newStatus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Theme.of(context).primaryColor.withAlpha((0.05 * 255).round()), borderRadius: BorderRadius.circular(8)),
      child: _isUploading
        ? const Center(child: CircularProgressIndicator()) 
        : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Lecturer Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(controller: _feedbackController, decoration: const InputDecoration(labelText: 'Feedback (optional)', border: OutlineInputBorder()), maxLines: 3),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file),
              label: const Text('Attach Image'),
              onPressed: _pickImage,
            ),
            if (_pickedImage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: kIsWeb ? Image.network(_pickedImage!.path, height: 100) : Image.file(File(_pickedImage!.path), height: 100),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(icon: const Icon(Icons.check_circle), label: const Text('Approve'), onPressed: () => _updateStatus('Approved'), style: TextButton.styleFrom(foregroundColor: Colors.green)),
                TextButton.icon(icon: const Icon(Icons.edit), label: const Text('Revision'), onPressed: () => _updateStatus('Revision'), style: TextButton.styleFrom(foregroundColor: Colors.orange)),
                TextButton.icon(icon: const Icon(Icons.cancel), label: const Text('Reject'), onPressed: () => _updateStatus('Rejected'), style: TextButton.styleFrom(foregroundColor: Colors.red)),
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
      stream: commentsRef.orderBy('createdAt', descending: false).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final comments = snapshot.data!.docs;
        if (comments.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('No comments yet.')));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final data = comments[index].data() as Map<String, dynamic>;
            final isMe = data['userId'] == currentUser.uid;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe) const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14)),
                  if (!isMe) const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(16).copyWith(
                          topLeft: !isMe ? const Radius.circular(0) : null,
                          topRight: isMe ? const Radius.circular(0) : null,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['text'] ?? '',
                            style: TextStyle(color: isMe ? Colors.white : null),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CommentInputField extends StatelessWidget {
  final TextEditingController commentController;
  final VoidCallback onPost;
  const _CommentInputField({required this.commentController, required this.onPost});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: commentController,
              decoration: const InputDecoration(
                hintText: 'Add a comment...',
                border: InputBorder.none,
                filled: false,
              ),
              maxLines: null,
            ),
          ),
          IconButton.filled(
            onPressed: onPost,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
