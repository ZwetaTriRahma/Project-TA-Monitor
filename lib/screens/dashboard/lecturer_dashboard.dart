
import 'dart:async';
import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:ta_monitor/screens/chat/chat_list_screen.dart';
import 'package:ta_monitor/screens/dashboard/lecturer_student_files_page.dart';
import 'package:ta_monitor/screens/notifications/notifications_page.dart';
import 'package:ta_monitor/screens/professional_screen.dart';
import 'package:ta_monitor/widgets/app_drawer.dart';
import 'package:ta_monitor/api/firebase_api.dart';

class LecturerDashboard extends StatefulWidget {
  const LecturerDashboard({super.key});

  @override
  State<LecturerDashboard> createState() => _LecturerDashboardState();
}

class _LecturerDashboardState extends State<LecturerDashboard> {
  late final User _currentUser;
  late final Future<DocumentSnapshot<Map<String, dynamic>>> _userDataFuture;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser!;
    _userDataFuture = FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).get();
    
    // Inisialisasi Notifikasi
    FirebaseApi().initNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: _DashboardAppBar(userDataFuture: _userDataFuture, currentUser: _currentUser),
      drawer: const AppDrawer(),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _userDataFuture,
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final lecturerData = userSnapshot.data?.data() ?? {};

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryBanner(context),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assigned Students',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _StudentList(lecturerId: _currentUser.uid),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ProfessionalScreen()));
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Professional'),
      ),
    );
  }

  Widget _buildSummaryBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
        ),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('lecturerId', isEqualTo: _currentUser.uid)
            .snapshots(),
        builder: (context, studentSnapshot) {
          final totalStudents = studentSnapshot.data?.docs.length ?? 0;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Faculty Overview',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryItem('Students', totalStudents.toString()),
                  _buildSummaryItem('Pending', '5'), // Placeholder logic for now
                  _buildSummaryItem('Completed', '2'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }
}

class _StudentList extends StatefulWidget {
  const _StudentList({required this.lecturerId});
  final String lecturerId;

  @override
  State<_StudentList> createState() => _StudentListState();
}

class _StudentListState extends State<_StudentList> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search for a student...',
              prefixIcon: const Icon(Icons.search),
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            ),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('lecturerId', isEqualTo: widget.lecturerId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const _EmptyStateView();
            }

            final filteredStudents = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final studentName = (data['fullName'] as String? ?? '').toLowerCase();
              final query = _searchQuery.toLowerCase();
              return studentName.contains(query);
            }).toList();

            if (filteredStudents.isEmpty) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('No students found.'),
              ));
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredStudents.length,
              itemBuilder: (context, index) {
                return _StudentCard(studentDoc: filteredStudents[index]);
              },
            );
          },
        ),
      ],
    );
  }
}

class _CalendarAndTasksSection extends StatefulWidget {
  final String lecturerId;
  final Map<String, dynamic> lecturerData;

  const _CalendarAndTasksSection({required this.lecturerId, required this.lecturerData});

  @override
  State<_CalendarAndTasksSection> createState() => _CalendarAndTasksSectionState();
}

class _CalendarAndTasksSectionState extends State<_CalendarAndTasksSection> {
  late final Stream<Map<String, dynamic>> _dataStream;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<String> _selectedEvents = [];

  @override
  void initState() {
    super.initState();
    _dataStream = _getCalendarAndTaskData();
    _selectedDay = _focusedDay;
  }

  Stream<Map<String, dynamic>> _getCalendarAndTaskData() async* {
    final studentDocs = await FirebaseFirestore.instance
        .collection('users')
        .where('lecturerId', isEqualTo: widget.lecturerId)
        .get();

    if (studentDocs.docs.isEmpty) {
      yield {'events': <DateTime, List<String>>{}, 'tasks': <Map<String, dynamic>>[]};
      return;
    }

    final studentIds = studentDocs.docs.map((doc) => doc.id).toList();
    final studentDataMap = {for (var doc in studentDocs.docs) doc.id: doc.data()};

    final fileStream = FirebaseFirestore.instance
        .collection('uploads')
        .where('userId', whereIn: studentIds)
        .orderBy('uploadedAt', descending: true)
        .snapshots();

    await for (final fileSnapshot in fileStream) {
      final fileDocs = fileSnapshot.docs;

      final events = LinkedHashMap<DateTime, List<String>>(
        equals: isSameDay,
        hashCode: (key) => key.day * 1000000 + key.month * 10000 + key.year,
      );
      
      for (final doc in fileDocs) {
        final data = doc.data();
        final timestamp = data['uploadedAt'] as Timestamp?;
        final uploaderId = data['userId'] as String?;
        final studentName = studentDataMap[uploaderId]?['fullName'] as String? ?? 'Unknown';
        final fileName = data['fileName'] as String? ?? 'file';
        final status = data['status'] as String? ?? 'Pending';

        if (timestamp != null) {
          final date = DateTime.utc(timestamp.toDate().year, timestamp.toDate().month, timestamp.toDate().day);
          final eventString = "$studentName: '$fileName' ($status)";
          if (events.containsKey(date)) {
            events[date]!.add(eventString);
          } else {
            events[date] = [eventString];
          }
        }
      }

      // [FIX] Show latest file task for each student
      final tasks = <Map<String, dynamic>>[];
      final processedStudentIds = <String>{};
      for (final doc in fileDocs) { // fileDocs is already sorted by date
        final data = doc.data();
        final uploaderId = data['userId'] as String?;
        if (uploaderId != null && !processedStudentIds.contains(uploaderId)) {
          final studentName = studentDataMap[uploaderId]?['fullName'] as String? ?? 'Unknown';
          final status = data['status'] as String? ?? 'Pending';
          tasks.add({'name': studentName, 'status': status});
          processedStudentIds.add(uploaderId);
        }
      }

      yield {'events': events, 'tasks': tasks};
    }
  }

  List<String> _getEventsForDay(DateTime day, LinkedHashMap<DateTime, List<String>> events) {
    return events[day] ?? [];
  }

 @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _dataStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData) {
          return const Center(child: Text("No data available."));
        }

        final events = snapshot.data!['events'] as LinkedHashMap<DateTime, List<String>>;
        final tasks = snapshot.data!['tasks'] as List<Map<String, dynamic>>;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CalendarView(
                events: events,
                focusedDay: _focusedDay,
                selectedDay: _selectedDay,
                getEventsForDay: (day) => _getEventsForDay(day, events),
                onDaySelected: (selected, focused) {
                  if (!isSameDay(_selectedDay, selected)) {
                    setState(() {
                      _selectedDay = selected;
                      _focusedDay = focused;
                      _selectedEvents = _getEventsForDay(selected, events);
                    });
                  }
                },
                onPageChanged: (focused) {
                  setState(() {
                    _focusedDay = focused;
                  });
                },
              ),
              const SizedBox(height: 16.0),
              ..._selectedEvents.map((event) => Container(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(event),
              )),
              const SizedBox(height: 24),
              _TasksView(
                lecturerData: widget.lecturerData,
                tasks: tasks,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CalendarView extends StatelessWidget {
  final LinkedHashMap<DateTime, List<String>> events;
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final Function(DateTime, DateTime) onDaySelected;
  final Function(DateTime) onPageChanged;
  final List<String> Function(DateTime) getEventsForDay;

  const _CalendarView({
    required this.events,
    required this.focusedDay,
    this.selectedDay,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.getEventsForDay,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: focusedDay,
          selectedDayPredicate: (day) => isSameDay(selectedDay, day),
          onDaySelected: onDaySelected,
          onPageChanged: onPageChanged,
          eventLoader: getEventsForDay,
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Colors.blue.shade200,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
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
  }
}

class _TasksView extends StatelessWidget {
  final Map<String, dynamic> lecturerData;
  final List<Map<String, dynamic>> tasks;

  const _TasksView({required this.lecturerData, required this.tasks});
  
  String get _facultyAndDepartment {
    final faculty = lecturerData['faculty'] as String? ?? 'N/A';
    final department = lecturerData['prodi'] as String? ?? 'N/A';
    return '$faculty - $department';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tasks ($_facultyAndDepartment)',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (tasks.isEmpty)
          const Text('No pending tasks.', style: TextStyle(color: Colors.grey))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              final isApproved = task['status'] == 'Approved';
              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    task['name'] as String,
                    style: TextStyle(
                      decoration: isApproved ? TextDecoration.lineThrough : null,
                      color: isApproved ? Colors.grey : null,
                    ),
                  ),
                  trailing: Chip(
                    label: Text(task['status'] as String),
                    backgroundColor: _getColorForStatus(task['status'] as String),
                     labelStyle: const TextStyle(color: Colors.white),
                  ),
                ),
              );
            },
          )
      ],
    );
  }
}


// --- WIDGETS (AppBar, etc.) ---

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
          final userName = snapshot.data?.data()?['fullName'] as String? ?? 'Lecturer';
          final title = snapshot.data?.data()?['title'] as String? ?? '';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Faculty Dashboard',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary.withOpacity(0.7),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '$userName, $title',
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
        const _RealTimeClock(),
        const SizedBox(width: 12),
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

class _RealTimeClock extends StatefulWidget {
  const _RealTimeClock();

  @override
  State<_RealTimeClock> createState() => _RealTimeClockState();
}

class _RealTimeClockState extends State<_RealTimeClock> {
  late Timer _timer;
  String _timeString = '';
  String _dateString = '';

  @override
  void initState() {
    super.initState();
    _updateTime(); // Initial update
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTime() {
    if (!mounted) return;
    final now = DateTime.now();
    final timeFormat = DateFormat('HH:mm:ss', 'id_ID');
    final dateFormat = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
    setState(() {
      _timeString = timeFormat.format(now);
      _dateString = dateFormat.format(now);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_timeString, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(_dateString, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
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
