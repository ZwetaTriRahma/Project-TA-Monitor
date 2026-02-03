import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ta_monitor/models/chat_message.dart';
import 'package:ta_monitor/models/chat_room.dart';
import 'package:ta_monitor/models/user_model.dart';
import 'package:ta_monitor/services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final ChatRoom chatRoom;
  final String currentUserId;

  const ChatScreen({
    super.key,
    required this.chatRoom,
    required this.currentUserId,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  late Future<UserModel> _otherUserFuture;

  @override
  void initState() {
    super.initState();
    _otherUserFuture = _getOtherUserDetails();
  }

  Future<UserModel> _getOtherUserDetails() async {
    final otherUserId = widget.chatRoom.users.firstWhere((id) => id != widget.currentUserId);
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(otherUserId).get();
    return UserModel.fromFirestore(userDoc.data()!, userDoc.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<UserModel>(
          future: _otherUserFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text('Loading...');
            }
            if (!snapshot.hasData) {
              return const Text('Chat Room');
            }
            final otherUser = snapshot.data!;
            return Row(
              children: [
                CircleAvatar(
                  backgroundImage: otherUser.profileImageUrl != null && otherUser.profileImageUrl!.isNotEmpty
                      ? NetworkImage(otherUser.profileImageUrl!)
                      : null,
                  child: otherUser.profileImageUrl == null || otherUser.profileImageUrl!.isEmpty
                      ? Text(otherUser.fullName.isNotEmpty ? otherUser.fullName[0].toUpperCase() : '?')
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(otherUser.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(otherUser.nimOrNidn ?? 'No ID', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(widget.chatRoom.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == widget.currentUserId;
                    return _buildMessageTile(message, isMe);
                  },
                );
              },
            ),
          ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

   Widget _buildMessageTile(ChatMessage message, bool isMe) {
    // ... (kode tidak berubah)
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).primaryColor : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Text(message.text, style: TextStyle(color: isMe ? Colors.white : null)),
      ),
    );
  }

  Widget _buildMessageComposer() {
    // ... (kode tidak berubah)
     return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Enter a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () {
              if (_messageController.text.isNotEmpty) {
                final message = ChatMessage(
                  id: '', 
                  senderId: widget.currentUserId,
                  text: _messageController.text,
                  timestamp: Timestamp.now(),
                );
                _chatService.sendMessage(widget.chatRoom.id, message);
                _messageController.clear();
              }
            },
          ),
        ],
      ),
    );
  }
}
