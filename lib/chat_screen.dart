import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String friendUid;
  final String friendName;

  const ChatScreen({super.key, required this.friendUid, required this.friendName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    _setupConversation();
  }

  Future<void> _setupConversation() async {
    final id = await ChatService().getOrCreateConversation(widget.friendUid);
    if (mounted) {
      setState(() => _conversationId = id);
    }
  }

  void _send() {
    if (_conversationId == null) return;
    ChatService().sendMessage(_conversationId!, _messageController.text);
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: Text(widget.friendName)),
      body: _conversationId == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: ChatService().getMessages(_conversationId!),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final messages = snapshot.data!.docs;

                      if (messages.isEmpty) {
                        return const Center(child: Text('Say hi 👋'));
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final data = messages[index].data() as Map<String, dynamic>;
                          final isMe = data['senderUid'] == myUid;

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.deepPurple : Colors.grey[300],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                data['text'] ?? '',
                                style: TextStyle(color: isMe ? Colors.white : Colors.black),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(hintText: 'Message...'),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.send), onPressed: _send),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}