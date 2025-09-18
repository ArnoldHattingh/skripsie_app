class ChatMessage {
  final bool isMe;
  final DateTime timestamp;
  final String userName;

  // Message kinds
  final String messageType; // 'text' | 'image_bw'

  // Text payload
  final String? text;

  // Black/white image payload (bit-packed)
  final ImageBitsBw? imageBw;

  ChatMessage({
    required this.isMe,
    required this.timestamp,
    required this.userName,
    required this.messageType,
    this.text,
    this.imageBw,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'isMe': isMe,
      'timestamp': timestamp.toIso8601String(),
      'userName': userName,
      'messageType': messageType,
    };
    if (messageType == 'text') {
      map['text'] = text ?? '';
    } else if (messageType == 'image_bw' && imageBw != null) {
      map['image_bw'] = imageBw!.toJson();
    }
    return map;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final type = (json['messageType'] as String?) ?? 'text';
    return ChatMessage(
      isMe: (json['isMe'] as bool?) ?? false,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userName: json['userName'] as String? ?? 'Unknown',
      messageType: type,
      text: type == 'text' ? json['text'] as String? ?? '' : null,
      imageBw: type == 'image_bw'
          ? ImageBitsBw.fromJson(json['image_bw'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ImageBitsBw {
  final int width;
  final int height;
  // Bit-packed row-major, MSB first in each byte; base64 encoded for JSON
  final String dataB64;

  ImageBitsBw({
    required this.width,
    required this.height,
    required this.dataB64,
  });

  Map<String, dynamic> toJson() => {
        'w': width,
        'h': height,
        'b64': dataB64,
      };

  factory ImageBitsBw.fromJson(Map<String, dynamic> json) => ImageBitsBw(
        width: (json['w'] as num).toInt(),
        height: (json['h'] as num).toInt(),
        dataB64: json['b64'] as String,
      );
}