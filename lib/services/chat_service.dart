
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ta_monitor/models/chat_message.dart';
import 'package:ta_monitor/models/chat_room.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper to generate a consistent, sorted chat room ID
  String _generateChatRoomId(String userId1, String userId2) {
    if (userId1.hashCode <= userId2.hashCode) {
      return '$userId1-$userId2';
    }
    return '$userId2-$userId1';
  }

  // [REFINED] Get or create a 1-on-1 chat room between two users.
  Future<ChatRoom> getOrCreateChatRoom(String user1Id, String user2Id) async {
    final chatRoomId = _generateChatRoomId(user1Id, user2Id);
    final docRef = _firestore.collection('chat_rooms').doc(chatRoomId);

    final snapshot = await docRef.get();

    if (snapshot.exists) {
      // If room exists, return it.
      return ChatRoom.fromFirestore(snapshot.data()!, snapshot.id);
    } else {
      // If room doesn't exist, create it.
      final newChatRoom = ChatRoom(
        id: chatRoomId, 
        // The `users` list is the most critical part.
        users: [user1Id, user2Id]..sort(), // Sort to ensure consistency in queries.
        // Deprecated fields are removed for simplicity.
      );
      await docRef.set(newChatRoom.toFirestore());
      return newChatRoom;
    }
  }

  // Send a message to a specific chat room
  Future<void> sendMessage(String chatRoomId, ChatMessage message) async {
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add(message.toFirestore());
  }

  // Get the stream of messages for a specific chat room
  Stream<QuerySnapshot> getMessages(String chatRoomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // You can add other chat-related functionalities here, like getting a list of all chat rooms for a user.
   Stream<QuerySnapshot> getChatRoomsStream(String userId) {
    return _firestore
        .collection('chat_rooms')
        .where('users', arrayContains: userId)
        .snapshots();
  }

}
