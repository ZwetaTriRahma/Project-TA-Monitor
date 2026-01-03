import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final User _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser!;
    _markNotificationsAsRead();
  }

  Future<void> _markNotificationsAsRead() async {
    final notificationsRef = FirebaseFirestore.instance.collection('notifications');
    final unreadNotifications = await notificationsRef
        .where('recipientId', isEqualTo: _currentUser.uid)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unreadNotifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('recipientId', isEqualTo: _currentUser.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No Notifications', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  Text('Your notifications will appear here', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: notifications.length,
            itemBuilder: (context, index) => _NotificationCard(notificationDoc: notifications[index]),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final QueryDocumentSnapshot notificationDoc;

  const _NotificationCard({required this.notificationDoc});

  @override
  Widget build(BuildContext context) {
    final data = notificationDoc.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'No Title';
    final body = data['body'] as String? ?? 'No content';
    final timestamp = data['createdAt'] as Timestamp?;
    final isRead = data['isRead'] as bool? ?? true;

    String formattedDate = 'date not available';
    if (timestamp != null) {
      final date = timestamp.toDate();
      formattedDate = '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isRead ? BorderSide.none : BorderSide(color: Colors.blue.shade700, width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: isRead ? Colors.grey.shade300 : Colors.blue.shade100,
          child: Icon(Icons.notifications, color: isRead ? Colors.grey.shade700 : Colors.blue.shade800),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$body\n\n$formattedDate', style: TextStyle(color: isRead ? Colors.grey.shade600 : Colors.black87)),
        isThreeLine: true,
      ),
    );
  }
}
