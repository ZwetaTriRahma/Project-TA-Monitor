import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SchedulingPage extends StatefulWidget {
  const SchedulingPage({super.key});

  @override
  State<SchedulingPage> createState() => _SchedulingPageState();
}

class _SchedulingPageState extends State<SchedulingPage> {
  Stream<QuerySnapshot> _getApprovedStudentsStream() {
    return FirebaseFirestore.instance
        .collection('uploads')
        .where('status', isEqualTo: 'Approved')
        .snapshots();
  }

  Future<void> _showSchedulingDialog(String studentId, String studentName) async {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );

    if (pickedDate == null) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime == null) return;

    selectedDate = pickedDate;
    selectedTime = pickedTime;

    final scheduleTimestamp = Timestamp.fromDate(
      DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute),
    );

    try {
      await FirebaseFirestore.instance.collection('users').doc(studentId).update({
        'defenseSchedule': scheduleTimestamp,
      });

      // Send notification to student
      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientId': studentId,
        'title': 'Defense Scheduled',
        'message': 'Your defense has been scheduled for ${DateFormat('yyyy-MM-dd HH:mm').format(scheduleTimestamp.toDate())}.',
        'createdAt': Timestamp.now(),
        'isRead': false,
      });

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Defense scheduled for $studentName'), backgroundColor: Colors.green),
      );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to schedule: $e'), backgroundColor: Colors.red),
      );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thesis Defense Scheduling'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getApprovedStudentsStream(),
        builder: (context, snapshot) {
          // [FIX] Show a more detailed error message
          if (snapshot.hasError) {
            // Firestore often suggests creating an index via a URL in the error message.
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Something went wrong. Please check your Firestore console for index creation prompts.\n\nError: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No students with approved thesis found.', style: TextStyle(color: Colors.grey)),
            );
          }

          final userIds = snapshot.data!.docs.map((doc) => doc['userId'] as String?).where((id) => id != null).toSet().toList();

          if (userIds.isEmpty) {
              return const Center(child: Text('Found approved files, but could not link them to users.'));
          }

          return ListView.builder(
            itemCount: userIds.length,
            itemBuilder: (context, index) {
              final userId = userIds[index]!;
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                      return const ListTile(title: Text('Loading student...'));
                  }
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return ListTile(title: Text('Student with ID $userId not found.'), leading: const Icon(Icons.error_outline, color: Colors.red));
                  }

                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  final studentName = userData['fullName'] ?? 'Unknown Student';
                  final scheduleTimestamp = userData['defenseSchedule'] as Timestamp?;

                  return Card(
                     margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                     child: ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(studentName),
                        subtitle: scheduleTimestamp != null
                            ? Text('Scheduled: ${DateFormat('d MMM y, HH:mm').format(scheduleTimestamp.toDate())}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                            : const Text('Not yet scheduled'),
                        trailing: ElevatedButton(
                          child: const Text('Schedule'),
                          onPressed: () => _showSchedulingDialog(userId, studentName),
                        ),
                     ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
