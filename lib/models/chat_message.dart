class ChatMessage {
  final bool isMe;
  final DateTime timestamp;
  final String userName;

  // Message kinds
  final String messageType; // 'text' | 'image_2bpp'

  // Text payload
  final String? text;

  // 2-bpp grayscale payload (4 levels, 4 pixels per byte)
  final Image2bpp? image2bpp;

  ChatMessage({
    required this.isMe,
    required this.timestamp,
    required this.userName,
    required this.messageType,
    this.text,
    this.image2bpp,
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
    } else if (messageType == 'image_2bpp' && image2bpp != null) {
      map['image_2bpp'] = image2bpp!.toJson();
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
      image2bpp: type == 'image_2bpp'
          ? Image2bpp.fromJson(json['image_2bpp'] as Map<String, dynamic>)
          : null,
    );
  }
}

class Image2bpp {
  final int width;
  final int height;
  // 2-bpp packed row-major, 4 pixels per byte, MSB first for first pixel; base64 encoded
  final String dataB64;

  Image2bpp({
    required this.width,
    required this.height,
    required this.dataB64,
  });

  Map<String, dynamic> toJson() => {'w': width, 'h': height, 'b64': dataB64};

  factory Image2bpp.fromJson(Map<String, dynamic> json) => Image2bpp(
    width: (json['w'] as num).toInt(),
    height: (json['h'] as num).toInt(),
    dataB64: json['b64'] as String,
  );
}
