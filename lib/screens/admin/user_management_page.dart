import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final Stream<QuerySnapshot> _usersStream = FirebaseFirestore.instance.collection('users').snapshots();

  Future<void> _updateUserStatus(String uid, {bool? isVerified, bool? isDisabled}) async {
    final Map<String, dynamic> dataToUpdate = {};
    if (isVerified != null) dataToUpdate['isVerified'] = isVerified;
    if (isDisabled != null) dataToUpdate['isDisabled'] = isDisabled;

    if (dataToUpdate.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update(dataToUpdate);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User status updated successfully'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update user status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // [NEW] Function to delete a user's Firestore document
  Future<void> _deleteUserDocument(String uid, String userName) async {
    // Confirmation dialog
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete all data for $userName? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User data deleted successfully.'), backgroundColor: Colors.green),
        );
        // DEVELOPER NOTE: Implement a Cloud Function to delete the corresponding Firebase Auth user.
        // Example: https://firebase.google.com/docs/functions/auth-events
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete user data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _usersStream,
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            children: snapshot.data!.docs.map((DocumentSnapshot document) {
              Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
              final String uid = document.id;
              final String role = data['role'] ?? 'N/A';
              final String fullName = data['fullName'] ?? 'No Name';
              final bool isVerified = data['isVerified'] ?? false;
              final bool isDisabled = data['isDisabled'] ?? false;
              
              if (role == 'Admin') {
                return const SizedBox.shrink();
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isDisabled ? Colors.grey[300] : Colors.white,
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(fullName[0].toUpperCase()),
                  ),
                  title: Text(fullName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['email'] ?? 'No email'),
                      Text('Role: $role'),
                      if (!isVerified) const Text('Status: Not Verified', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      if (isDisabled) const Text('Status: Disabled', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'verify') {
                        _updateUserStatus(uid, isVerified: true);
                      }
                      if (value == 'toggle_disable') {
                        _updateUserStatus(uid, isDisabled: !isDisabled);
                      }
                      if (value == 'delete') {
                        _deleteUserDocument(uid, fullName);
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      if (!isVerified)
                        const PopupMenuItem<String>(
                          value: 'verify',
                          child: Text('Verify User'),
                        ),
                      PopupMenuItem<String>(
                        value: 'toggle_disable',
                        child: Text(isDisabled ? 'Enable User' : 'Disable User'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Delete User', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
