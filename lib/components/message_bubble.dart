import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:skripsie/constants.dart';
import 'package:skripsie/models/chat_message.dart';
import 'package:skripsie/components/two_bpp_image_view.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: message.isMe
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isMe ? 16 : 4),
            bottomRight: Radius.circular(message.isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: message.isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!message.isMe) ...[
              Text(
                message.userName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (message.messageType == 'text' && message.text != null)
              Text(
                message.text!,
                style: TextStyle(
                  color: message.isMe
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else if (message.messageType == 'image_2bpp' &&
                message.image2bpp != null)
              _TwoBppInline(image: message.image2bpp!, isMe: message.isMe),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(message.timestamp),
              style: TextStyle(
                fontSize: 10,
                color: message.isMe
                    ? Theme.of(
                        context,
                      ).colorScheme.onPrimary.withValues(alpha: 0.7)
                    : Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

class _TwoBppInline extends StatelessWidget {
  final Image2bpp image;
  final bool isMe;
  const _TwoBppInline({required this.image, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final faintBg = isMe
        ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.06)
        : Theme.of(context).colorScheme.surfaceTint.withValues(alpha: 0.06);
    final header = {
      'width': image.width,
      'height': image.height,
      'format': '2bpp',
      'packed': true,
    };
    final data = base64Decode(image.dataB64);
    final map = {'header': header, 'bytes': data};
    final maxDisplayWidth = MediaQuery.of(context).size.width * 0.55;
    final scale = (maxDisplayWidth / image.width).clamp(3.0, 8.0).floor();
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: faintBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: TwoBppImageView(
          twoBppMap: map,
          pixelScale: scale,
          
        ),
      ),
    );
  }
}
