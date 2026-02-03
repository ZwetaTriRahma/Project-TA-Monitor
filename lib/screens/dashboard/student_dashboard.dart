import 'dart:collection';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:ta_monitor/screens/chat/chat_screen.dart';
import 'package:ta_monitor/screens/details/file_details_page.dart';
import 'package:ta_monitor/screens/notifications/notifications_page.dart';
import 'package:ta_monitor/services/chat_service.dart';
import 'package:ta_monitor/widgets/app_drawer.dart';
import 'package:ta_monitor/api/firebase_api.dart';

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
  final ChatService _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser!;
    _userDataFuture = FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).get();
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text));
    // Inisialisasi Notifikasi
    FirebaseApi().initNotifications();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: _DashboardAppBar(userDataFuture: _userDataFuture, currentUser: _currentUser),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgressBanner(context),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  _buildStatsGrid(context),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for a file...',
                      prefixIcon: const Icon(Icons.search),
                      fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Submissions',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          // Implement filter/full list
                        },
                        icon: const Icon(Icons.sort, size: 18),
                        label: const Text('Latest First'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SubmissionsList(currentUser: _currentUser, searchQuery: _searchQuery),
                  const SizedBox(height: 80), // Space for FAB
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _UploadButton(currentUser: _currentUser, userDataFuture: _userDataFuture),
    );
  }

  Widget _buildProgressBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.8),
          ],
        ),
      ),
      child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _userDataFuture,
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          final progress = (data?['progress'] as num? ?? 0).toDouble(); // e.g. 0.65 for 65%
          return Column(
            children: [
              Row(
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: Colors.white24,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Overall Progress',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          '${(progress * 100).toInt()}% Completed',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white10,
                          color: Colors.lightBlueAccent,
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('uploads')
          .where('userId', isEqualTo: _currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final pending = docs.where((d) => d['status'] == 'Pending').length;
        final revision = docs.where((d) => d['status'] == 'Revision').length;
        final approved = docs.where((d) => d['status'] == 'Approved').length;

        return GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.9,
          children: [
            _buildStatCard(context, 'Pending', pending.toString(), Colors.orange, Icons.hourglass_empty),
            _buildStatCard(context, 'Revision', revision.toString(), Colors.blue, Icons.edit_note),
            _buildStatCard(context, 'Approved', approved.toString(), Colors.green, Icons.check_circle_outline),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, Color color, IconData icon) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmissionsList extends StatelessWidget {
  const _SubmissionsList({required this.currentUser, required this.searchQuery});

  final User currentUser;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('uploads')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const _EmptyStateView();
        }

        final filteredFiles = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final fileName = (data['fileName'] as String? ?? '').toLowerCase();
          return fileName.contains(searchQuery.toLowerCase());
        }).toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredFiles.length,
          itemBuilder: (context, index) => _FileCard(fileDoc: filteredFiles[index]),
        );
      },
    );
  }
}

class _CalendarSection extends StatefulWidget {
  final String userId;
  const _CalendarSection({required this.userId});

  @override
  State<_CalendarSection> createState() => _CalendarSectionState();
}

class _CalendarSectionState extends State<_CalendarSection> {
  late final Stream<LinkedHashMap<DateTime, List<String>>> _eventsStream;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _eventsStream = _getEventsStream();
    _selectedDay = _focusedDay;
  }

  Stream<LinkedHashMap<DateTime, List<String>>> _getEventsStream() async* {
    final fileStream = FirebaseFirestore.instance
        .collection('uploads')
        .where('userId', isEqualTo: widget.userId)
        .where('status', isEqualTo: 'Revision')
        .snapshots();

    await for (final snapshot in fileStream) {
      final events = LinkedHashMap<DateTime, List<String>>(
        equals: isSameDay,
        hashCode: (key) => key.day * 1000000 + key.month * 10000 + key.year,
      );

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final deadline = (data['revisionDeadline'] as Timestamp?)?.toDate();
        final fileName = data['fileName'] as String? ?? 'file';

        if (deadline != null) {
          final date = DateTime.utc(deadline.year, deadline.month, deadline.day);
          final eventString = "Deadline for: '$fileName'";

          if (events.containsKey(date)) {
            events[date]!.add(eventString);
          } else {
            events[date] = [eventString];
          }
        }
      }

      yield events;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LinkedHashMap<DateTime, List<String>>>(
      stream: _eventsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final events = snapshot.data ?? LinkedHashMap<DateTime, List<String>>(
          equals: isSameDay,
          hashCode: (key) => key.day * 1000000 + key.month * 10000 + key.year,
        );

        return Card(
          margin: const EdgeInsets.all(12.0),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: (day) => events[day] ?? [],
              onDaySelected: (selected, focused) {
                if (!isSameDay(_selectedDay, selected)) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                }
              },
              onPageChanged: (focused) {
                _focusedDay = focused;
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.blue.shade200,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _DashboardAppBar({required this.userDataFuture, required this.currentUser});

  final Future<DocumentSnapshot<Map<String, dynamic>>> userDataFuture;
  final User currentUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      surfaceTintColor: Colors.transparent,
      title: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: userDataFuture,
        builder: (context, snapshot) {
          final userName = snapshot.data?.data()?['fullName'] as String? ?? 'Student';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Student Console',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary.withOpacity(0.7),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                userName,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        _buildNotificationAction(context),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildNotificationAction(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: currentUser.uid)
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return IconButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsPage()),
          ),
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text(count.toString()),
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
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
  final String _cloudinaryCloudName = 'dl7kvbaao';
  final String _cloudinaryApiKey = '847986695727928';
  final String _cloudinaryApiSecret = 'BMwsVLv24SpRrzuo7_YA9PnC_ys';

  Future<void> _uploadFile() async {
    setState(() => _isUploading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _isUploading = false);
        return;
      }

      final pickedFile = result.files.single;
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/raw/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['api_key'] = _cloudinaryApiKey
        ..fields['upload_preset'] = 'default';

      if (kIsWeb) {
        if (pickedFile.bytes == null) throw Exception("File bytes are null on web");
        request.files.add(http.MultipartFile.fromBytes('file', pickedFile.bytes!, filename: pickedFile.name));
      } else {
        if (pickedFile.path == null) throw Exception("File path is null on mobile");
        request.files.add(await http.MultipartFile.fromPath('file', pickedFile.path!));
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final jsonMap = jsonDecode(responseString);

        debugPrint('Response JSON: $jsonMap');

        if (jsonMap.containsKey('error')) {
          throw Exception('Cloudinary error: ${jsonMap['error']['message']}');
        }

        final downloadUrl = jsonMap['secure_url'];
        debugPrint('Download URL: $downloadUrl');

        await FirebaseFirestore.instance.collection('uploads').add({
          'userId': widget.currentUser.uid,
          'fileName': pickedFile.name,
          'downloadUrl': downloadUrl,
          'uploadedAt': Timestamp.now(),
          'status': 'Pending',
          'title': pickedFile.name,
        });

        final userData = await widget.userDataFuture;
        final studentName = userData.data()?['fullName'] as String? ?? 'A student';
        final lecturerId = userData.data()?['lecturerId'] as String?;

        if (lecturerId != null) {
          try {
            await FirebaseFirestore.instance.collection('notifications').add({
              'recipientId': lecturerId,
              'title': 'New File Uploaded',
              'body': '$studentName has uploaded a new file: ${pickedFile.name}',
              'createdAt': FieldValue.serverTimestamp(),
              'isRead': false,
            });
          } catch (e) {
            debugPrint('Failed to send notification: $e');
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File uploaded successfully'), backgroundColor: Colors.green),
          );
        }
      } else {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        debugPrint('Cloudinary response: $responseString');
        final jsonMap = jsonDecode(responseString);
        final errorMessage = jsonMap['error']?['message'] ?? 'Unknown error';
        throw Exception('Failed to upload to Cloudinary: $errorMessage');
      }
    } catch (e, s) {
      debugPrint("Error uploading file: $e");
      debugPrint(s.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
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
      heroTag: 'upload_fab',
      icon: _isUploading ? const SizedBox.shrink() : const Icon(Icons.upload_file),
      label: _isUploading
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text('Upload File'),
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
          Text('Press the upload button to add your first file', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

// [MODIFIED] The FileCard now displays deadline information
class _FileCard extends StatelessWidget {
  final QueryDocumentSnapshot fileDoc;

  const _FileCard({required this.fileDoc});

  Future<void> _showDeleteConfirmationDialog(BuildContext context, String? downloadUrl) async {
    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete the record of this file?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await fileDoc.reference.delete();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('File record deleted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete file record: $e'),
                        backgroundColor: Colors.red,
                      ),
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
      case 'Revision':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        icon = Icons.edit;
        break;
      default:
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
    final status = data['status'] as String? ?? 'Pending';
    // [NEW] Get deadline from Firestore data
    final deadline = (data['revisionDeadline'] as Timestamp?)?.toDate();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16.0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => FileDetailsPage(fileId: fileDoc.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.article_outlined, size: 36, color: Colors.blueGrey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        _buildStatusChip(status),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _showDeleteConfirmationDialog(context, downloadUrl);
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
              // [NEW] Deadline reminder section
              if (status == 'Revision' && deadline != null) ...[
                const Divider(height: 20),
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Revision deadline: ${DateFormat('d MMMM yyyy').format(deadline)}',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                )
              ],
            ],
          ),
        ),
      ),
    );
  }
}