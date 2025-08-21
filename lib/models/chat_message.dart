class ChatMessage {
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final String userName;

  ChatMessage({
    required this.text,
    required this.isMe,
    required this.timestamp,
    required this.userName,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isMe': isMe,
      'timestamp': timestamp.toIso8601String(),
      'userName': userName,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'] as String,
      isMe: json['isMe'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userName: json['userName'] as String,
    );
  }
}