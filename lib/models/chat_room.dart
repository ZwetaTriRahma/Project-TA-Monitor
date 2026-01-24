
// Represents a chat room in the application
class ChatRoom {
  final String id;
  final List<String> users; // List of participant user IDs

  ChatRoom({
    required this.id,
    required this.users,
  });

  // Factory constructor to create a ChatRoom from Firestore document data
  factory ChatRoom.fromFirestore(Map<String, dynamic> data, String documentId) {
    return ChatRoom(
      id: documentId,
      users: List<String>.from(data['users'] ?? []),
    );
  }

  // Converts the ChatRoom object to a map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'users': users,
    };
  }
}
