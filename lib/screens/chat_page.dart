import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skripsie/components/message_bubble.dart';
import 'package:skripsie/providers/bluetooth_provider.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final bluetoothProvider = Provider.of<BluetoothProvider>(context, listen: false);
    final success = await bluetoothProvider.sendMessage(_messageController.text);
    if (_messageController.text.isEmpty) {
      return;
    }
    
    if (success) {
      _messageController.clear();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to send message'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothProvider>(
      builder: (context, bluetoothProvider, child) {
        final theme = Theme.of(context);
        
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: theme.colorScheme.background,
            appBar: AppBar(
              backgroundColor: theme.colorScheme.surface,
              elevation: 2,
              shadowColor: Colors.black12,
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.bluetooth,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bluetoothProvider.connectedDevice?.name ?? 'Unknown Device',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: bluetoothProvider.isConnected ? Colors.green : Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              bluetoothProvider.isConnected ? 'Connected' : 'Disconnected',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                if (!bluetoothProvider.isConnected)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Please restart the app to reconnect'),
                          backgroundColor: theme.colorScheme.secondary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: bluetoothProvider.messages.isEmpty
                        ? Center(
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 64,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No messages yet',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Start a conversation!',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                            itemCount: bluetoothProvider.messages.length,
                            itemBuilder: (context, index) {
                              final message = bluetoothProvider.messages[bluetoothProvider.messages.length - 1 - index];
                              return MessageBubble(message: message);
                            },
                          ),
                  ),
                  if (bluetoothProvider.sendProgressSent != null && bluetoothProvider.sendProgressTotal != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: bluetoothProvider.sendProgressTotal == 0
                                  ? null
                                  : (bluetoothProvider.sendProgressSent! / bluetoothProvider.sendProgressTotal!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${bluetoothProvider.sendProgressSent}/${bluetoothProvider.sendProgressTotal}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  if (bluetoothProvider.recvProgressReceived != null && bluetoothProvider.recvProgressTotal != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: bluetoothProvider.recvProgressTotal == 0
                                  ? null
                                  : (bluetoothProvider.recvProgressReceived! / bluetoothProvider.recvProgressTotal!),
                              color: theme.colorScheme.secondary,
                              backgroundColor: theme.colorScheme.secondaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Downloading ${bluetoothProvider.recvProgressReceived}/${bluetoothProvider.recvProgressTotal}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: TextField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: bluetoothProvider.isConnected ? 'Type a message...' : 'Not connected',
                                hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                enabled: bluetoothProvider.isConnected && !bluetoothProvider.isSending,
                              ),
                              style: theme.textTheme.bodyLarge,
                              onSubmitted: (_) => _sendMessage(),
                              minLines: 1,
                              maxLines: 7,
                              textCapitalization: TextCapitalization.sentences,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: bluetoothProvider.isConnected && !bluetoothProvider.isSending 
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceVariant,
                            shape: BoxShape.circle,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: bluetoothProvider.isConnected && !bluetoothProvider.isSending ? _sendMessage : null,
                              borderRadius: BorderRadius.circular(24),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: bluetoothProvider.isSending
                                    ? SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.send_rounded,
                                        color: bluetoothProvider.isConnected
                                            ? theme.colorScheme.onPrimary
                                            : theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                                        size: 24,
                                      ),
                              ),
                            ),
                          ),
                        ),
                        // const SizedBox(width: 8),
                        // Tooltip(
                        //   message: 'Send low-res image',
                        //   child: Container(
                        //     decoration: BoxDecoration(
                        //       color: bluetoothProvider.isConnected && !bluetoothProvider.isSending 
                        //           ? theme.colorScheme.secondary
                        //           : theme.colorScheme.surfaceVariant,
                        //       shape: BoxShape.circle,
                        //     ),
                        //     child: Material(
                        //       color: Colors.transparent,
                        //       child: InkWell(
                        //         onTap: bluetoothProvider.isConnected && !bluetoothProvider.isSending
                        //             ? () async {
                        //                 // Capture from camera, convert to 1-bit 128x96, send
                        //                 await bluetoothProvider.captureAndSendBwImage(targetW: 128, targetH: 96);
                        //               }
                        //             : null,
                        //         borderRadius: BorderRadius.circular(24),
                        //         child: Padding(
                        //           padding: const EdgeInsets.all(12),
                        //           child: Icon(
                        //             Icons.photo_camera_rounded,
                        //             color: bluetoothProvider.isConnected
                        //                 ? theme.colorScheme.onSecondary
                        //                 : theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                        //             size: 22,
                        //           ),
                        //         ),
                        //       ),
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}