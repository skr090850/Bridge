import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chat_message_model.dart';

class ChatScreen extends StatefulWidget {
  final int currentUserId;
  final int chatPartnerId;
  final String chatPartnerName;

  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.chatPartnerId,
    required this.chatPartnerName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  late Future<List<ChatMessage>> _messagesFuture;

  @override
  void initState() {
    super.initState();
    _messagesFuture = _fetchMessages();
  }

  Future<List<ChatMessage>> _fetchMessages() async {
        final url = Uri.parse(
        'http://183.82.115.221/Bridge/BridgeApi/api/bridge/GetChatMessages?fromId=${widget.currentUserId}&toId=${widget.chatPartnerId}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((json) => ChatMessage.fromJson(json, widget.currentUserId))
            .toList();
      } else {
        throw Exception('Failed to load messages');
      }
    } catch (e) {
      debugPrint("API fetch failed, showing dummy data. Error: $e");
      return [
        ChatMessage(senderName: 'Bhavana Aitha', text: 'Sir', time: '7:40PM', isMe: false),
        ChatMessage(senderName: widget.chatPartnerName, text: 'Coordinate Samatha', time: '7:41PM', isMe: true),
      ];
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    
    final messageText = _messageController.text;
    _messageController.clear();

    final url = Uri.parse('http://183.82.115.221/Bridge/BridgeApi/api/bridge/SendMessage');
    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fromId': widget.currentUserId,
          'toId': widget.chatPartnerId,
          'message': messageText,
        }),
      );
      setState(() {
        _messagesFuture = _fetchMessages();
      });
    } catch (e) {
      debugPrint("Failed to send message: $e");
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to send message")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chatPartnerName),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<ChatMessage>>(
              future: _messagesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }
                final messages = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _buildMessageBubble(
                      isMe: message.isMe,
                      sender: message.senderName,
                      text: message.text,
                      time: message.time,
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
      {required bool isMe,
      required String sender,
      required String text,
      required String time}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.grey[200],
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                sender,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12, color: Theme.of(context).colorScheme.primary),
              ),
            Text(text),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Message',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
               onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

