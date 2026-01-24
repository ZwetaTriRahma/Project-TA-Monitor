
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ta_monitor/models/chat_room.dart';
import 'package:ta_monitor/screens/chat/chat_screen.dart';
import 'package:ta_monitor/models/user_model.dart'; 

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Fetches the details of the other user in the chat.
  Future<UserModel?> _getOtherUserDetails(List<String> userIds) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return null;

    // Find the ID of the other user in the chat room.
    final otherUserId = userIds.firstWhere((id) => id != currentUserId, orElse: () => '');
    if (otherUserId.isNotEmpty) {
      final userDoc = await _firestore.collection('users').doc(otherUserId).get();
      if(userDoc.exists) {
        // Create a UserModel from the document.
        return UserModel.fromFirestore(userDoc.data()!, userDoc.id);
      }
    }
    return null; 
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
        return Scaffold(
            appBar: AppBar(title: const Text("Chats")),
            body: const Center(child: Text("Please log in to see your chats.")),
        );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chats"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('chat_rooms')
            .where('users', arrayContains: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No chat rooms found."));
          }

          final chatRooms = snapshot.data!.docs
              .map((doc) => ChatRoom.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
              .toList();

          return ListView.builder(
            itemCount: chatRooms.length,
            itemBuilder: (context, index) {
              final chatRoom = chatRooms[index];
              return FutureBuilder<UserModel?>(
                future: _getOtherUserDetails(chatRoom.users),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(title: Text("Loading chat..."), leading: CircularProgressIndicator());
                  }
                  if (!userSnapshot.hasData || userSnapshot.data == null) {
                     return const ListTile(title: Text('Could not load user details.'), leading: Icon(Icons.error));
                  }

                  final otherUser = userSnapshot.data!;
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(otherUser.fullName.isNotEmpty ? otherUser.fullName[0].toUpperCase() : '?'),
                    ),
                    title: Text(otherUser.fullName),
                    // [CORRECTED] Use nimOrNidn from the otherUser model.
                    subtitle: Text(otherUser.nimOrNidn ?? 'No ID available'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            chatRoom: chatRoom,
                            currentUserId: currentUserId,
                          ),
                        ),
                      );
                    },
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
