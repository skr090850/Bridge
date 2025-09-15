import 'package:intl/intl.dart';

class ChatMessage {
  final String senderName;
  final String text;
  final String time;
  final bool isMe;

  ChatMessage({
    required this.senderName,
    required this.text,
    required this.time,
    required this.isMe,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, int currentUserId) {
    final int senderId = json['senderId'] ?? 0;
    
    // API se aa rahe timestamp ko format kiya gaya hai
    String formattedTime = 'N/A';
    if (json['timestamp'] != null) {
      try {
        final dateTime = DateTime.parse(json['timestamp']);
        formattedTime = DateFormat('h:mm a').format(dateTime);
      } catch (e) {
        // Handle parsing error if necessary
      }
    }

    return ChatMessage(
      senderName: json['senderName'] ?? 'Unknown',
      text: json['message'] ?? '',
      time: formattedTime,
      isMe: senderId == currentUserId,
    );
  }
}
