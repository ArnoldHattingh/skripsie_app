import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:skripsie/models/chat_message.dart';

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
          crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!message.isMe) ...[
              Text(
                message.userName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
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
            else if (message.messageType == 'image_bw' && message.imageBw != null)
              _BwImage(bits: message.imageBw!, isMe: message.isMe)
            else if (message.messageType == 'img_bw' && message.imageBw != null)
              _BwImage(bits: message.imageBw!, isMe: message.isMe),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(message.timestamp),
              style: TextStyle(
                fontSize: 10,
                color: message.isMe
                    ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)
                    : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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

class _BwImage extends StatelessWidget {
  final ImageBitsBw bits;
  final bool isMe;
  const _BwImage({required this.bits, required this.isMe});

  @override
  Widget build(BuildContext context) {
    try {
      final data = base64Decode(bits.dataB64);
      var pixels = _unpackBits(data, bits.width, bits.height);
      // If everything decoded as off (all zeros), auto-invert as a fallback
      final anyOn = pixels.any((e) => e != 0);
      if (!anyOn) {
        pixels = pixels.map((e) => e == 0 ? 1 : 0).toList(growable: false);
      }
      // Determine pixel size based on target width (keep bubble compact)
      final maxDisplayWidth = MediaQuery.of(context).size.width * 0.55;
      final pxSize = (maxDisplayWidth / bits.width).clamp(3.0, 6.0);
      final faintOffColor = isMe
          ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.08)
          : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.06);
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isMe
              ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.06)
              : Theme.of(context).colorScheme.surfaceTint.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(bits.height, (y) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(bits.width, (x) {
                final on = pixels[y * bits.width + x] != 0;
                return Container(
                  width: pxSize,
                  height: pxSize,
                  color: on
                      ? (isMe
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface)
                      : faintOffColor,
                );
              }),
            );
          }),
        ),
      );
    } catch (_) {
      return const Text('[image]');
    }
  }

  List<int> _unpackBits(List<int> bytes, int w, int h) {
    final total = w * h;
    final out = List<int>.filled(total, 0);
    for (int i = 0; i < total; i++) {
      final byteIndex = i >> 3;
      final bitIndex = 7 - (i & 7);
      if (byteIndex < bytes.length) {
        final bit = (bytes[byteIndex] >> bitIndex) & 1;
        out[i] = bit;
      }
    }
    return out;
  }
}