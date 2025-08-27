import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:skripsie/models/group_connection_info.dart';
import 'package:skripsie/providers/bluetooth_provider.dart';
import 'package:skripsie/screens/chat_page.dart';
import 'package:skripsie/screens/find_friend.dart';
import 'package:skripsie/screens/join_or_create_group_screen.dart';
import 'package:skripsie/screens/qr_scan_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothProvider>(
      builder: (context, bluetoothProvider, child) {
        return Scaffold(
          appBar: AppBar(
            surfaceTintColor: Colors.transparent,
            title: Container(
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'lib/assets/Logo Design.png',
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Friend Radar',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                        ),
                      ],
                    ),
                  ),
                  // Connection Status Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: bluetoothProvider.isConnected
                          ? Colors.green[50]
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: bluetoothProvider.isConnected
                            ? Colors.green[200]!
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: bluetoothProvider.isConnected
                                ? Colors.green
                                : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          bluetoothProvider.isConnected ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: bluetoothProvider.isConnected
                                ? Colors.green[700]
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            backgroundColor: const Color(0xFFF8F9FA),
          ),
          backgroundColor: const Color(0xFFF8F9FA),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        // Group Chat Overview Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Group Avatar Section
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          Theme.of(context).colorScheme.primary
                                              .withOpacity(0.1),
                                          Theme.of(context)
                                              .colorScheme
                                              .secondary
                                              .withOpacity(0.1),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: Icon(
                                      bluetoothProvider.isConnected
                                          ? Icons.groups_rounded
                                          : Icons.person_add_rounded,
                                      size: 50,
                                      color: bluetoothProvider.isConnected
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Colors.grey[400],
                                    ),
                                  ),
                                  if (bluetoothProvider.isConnected)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 3,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Status Text
                              Text(
                                bluetoothProvider.isConnected
                                    ? 'Group Connected'
                                    : 'Ready to Connect',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                              ),

                              const SizedBox(height: 8),

                              Text(
                                bluetoothProvider.isConnected
                                    ? 'You can now chat and find friends in your group'
                                    : 'Connect your device to start chatting with friends',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.grey[600]),
                                textAlign: TextAlign.center,
                              ),

                              // Device Info Section
                              if (bluetoothProvider.isConnected &&
                                  bluetoothProvider.connectedDevice !=
                                      null) ...[
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.bluetooth_connected,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              bluetoothProvider
                                                  .connectedDevice!
                                                  .name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              'Connected Device',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (bluetoothProvider.batteryPercentage !=
                                          null) ...[
                                        Icon(
                                          Icons.battery_full,
                                          color: Colors.green[600],
                                          size: 20,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${bluetoothProvider.batteryPercentage}%',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green[600],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (bluetoothProvider.isConnected) ...[
                          _ModernActionButton(
                            icon: Icons.chat_bubble_rounded,
                            label: 'Open Chat',
                            subtitle: bluetoothProvider.unreadMessageCount > 0
                                ? '${bluetoothProvider.unreadMessageCount} unread message${bluetoothProvider.unreadMessageCount > 1 ? 's' : ''}'
                                : 'Start messaging with your group',
                            isPrimary: true,
                            hasNotification:
                                bluetoothProvider.unreadMessageCount > 0,
                            notificationCount:
                                bluetoothProvider.unreadMessageCount,
                            onTap: () {
                              // Mark messages as read when opening chat
                              bluetoothProvider.markMessagesAsRead();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const ChatPage(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Friends List Section
                        if (bluetoothProvider.isConnected &&
                            bluetoothProvider.friends != null &&
                            bluetoothProvider.friends!.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Group Members',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          onTap: () {
                                            showQRCode(
                                              context,
                                              bluetoothProvider
                                                  .groupConnectionInfo!,
                                            );
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.person_add_rounded,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Invite',
                                                  style: TextStyle(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ...bluetoothProvider.friends!.map((friend) {
                                  final isActive =
                                      DateTime.now()
                                          .difference(friend.lastSeen)
                                          .inMinutes <
                                      3;
                                  final hasLocation =
                                      friend.latitude != null &&
                                      friend.longitude != null;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: friend.isMe
                                          ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.1)
                                          : Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: friend.isMe
                                          ? Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.3),
                                            )
                                          : null,
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: hasLocation && !friend.isMe
                                            ? () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        FindFriendPage(
                                                          friendId: friend.id,
                                                        ),
                                                  ),
                                                );
                                              }
                                            : null,
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              Stack(
                                                children: [
                                                  Container(
                                                    width: 48,
                                                    height: 48,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: friend.isMe
                                                          ? Theme.of(context)
                                                                .colorScheme
                                                                .primary
                                                          : Colors.grey[400],
                                                    ),
                                                    child: Icon(
                                                      friend.isMe
                                                          ? Icons.person_rounded
                                                          : Icons
                                                                .person_outline_rounded,
                                                      color: Colors.white,
                                                      size: 24,
                                                    ),
                                                  ),
                                                  Positioned(
                                                    right: 0,
                                                    bottom: 0,
                                                    child: Container(
                                                      width: 16,
                                                      height: 16,
                                                      decoration: BoxDecoration(
                                                        color: isActive
                                                            ? Colors.green
                                                            : Colors.grey,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: Colors.white,
                                                          width: 2,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(
                                                          friend.name,
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontSize: 16,
                                                              ),
                                                        ),
                                                        if (friend.isMe) ...[
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 2,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .primary,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                            ),
                                                            child: const Text(
                                                              'You',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Container(
                                                          width: 8,
                                                          height: 8,
                                                          decoration:
                                                              BoxDecoration(
                                                                color: isActive
                                                                    ? Colors
                                                                          .green
                                                                    : Colors
                                                                          .grey,
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Expanded(
                                                          child: Row(
                                                            children: [
                                                              Text(
                                                                isActive
                                                                    ? 'Active'
                                                                    : 'Inactive',
                                                                style: TextStyle(
                                                                  color:
                                                                      isActive
                                                                      ? Colors
                                                                            .green[700]
                                                                      : Colors
                                                                            .grey[600],
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                              ),
                                                              if (!isActive) ...[
                                                                const SizedBox(
                                                                  width: 8,
                                                                ),
                                                                Flexible(
                                                                  child: Text(
                                                                    'Last seen ${_formatLastSeen(friend.lastSeen)}',
                                                                    style: TextStyle(
                                                                      color: Colors
                                                                          .grey[500],
                                                                      fontSize:
                                                                          12,
                                                                    ),
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (hasLocation &&
                                                        !friend.isMe) ...[
                                                      const SizedBox(height: 8),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.location_on,
                                                            color: Colors
                                                                .green[600],
                                                            size: 16,
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            'Tap to view location',
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .green[600],
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              if (hasLocation && !friend.isMe)
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green[50],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    Icons.my_location_rounded,
                                                    color: Colors.green[600],
                                                    size: 20,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // Action Buttons Section
                        Column(
                          children: [
                            _ModernActionButton(
                              icon: bluetoothProvider.isConnected
                                  ? Icons.bluetooth_disabled_rounded
                                  : Icons.qr_code_scanner_rounded,
                              label: bluetoothProvider.isConnected
                                  ? 'Disconnect Device'
                                  : 'Connect Device',
                              subtitle: bluetoothProvider.isConnected
                                  ? 'Disconnect from Bluetooth device'
                                  : 'Scan QR code to join a group',
                              isDestructive: bluetoothProvider.isConnected,
                              onTap: () {
                                if (bluetoothProvider.isConnected) {
                                  bluetoothProvider.disconnect();
                                }
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (context) => const QRScanPage(),
                                  ),
                                  (route) => false,
                                );
                              },
                            ),
                          ],
                        ),

                        // Add some bottom padding for better scrolling experience
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final difference = DateTime.now().difference(lastSeen);
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

class HomeScreenWrapper extends StatelessWidget {
  const HomeScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BluetoothProvider>(context);
    return provider.groupConnectionInfo != null
        ? const HomeScreen()
        : const JoinOrCreateGroupScreen();
  }
}

class _ModernActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isDestructive;
  final bool hasNotification;
  final int notificationCount;

  const _ModernActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isPrimary = false,
    this.isDestructive = false,
    this.hasNotification = false,
    this.notificationCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color backgroundColor;
    Color iconColor;
    Color textColor;
    Color subtitleColor;

    if (isPrimary) {
      backgroundColor = theme.colorScheme.primary;
      iconColor = Colors.white;
      textColor = Colors.white;
      subtitleColor = Colors.white.withOpacity(0.8);
    } else if (isDestructive) {
      backgroundColor = Colors.red[50]!;
      iconColor = Colors.red[600]!;
      textColor = Colors.red[700]!;
      subtitleColor = Colors.red[500]!;
    } else {
      backgroundColor = Colors.white;
      iconColor = theme.colorScheme.primary;
      textColor = Colors.black87;
      subtitleColor = Colors.grey[600]!;
    }

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      elevation: isPrimary ? 2 : 0,
      shadowColor: isPrimary
          ? theme.colorScheme.primary.withOpacity(0.3)
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          decoration: isPrimary
              ? null
              : BoxDecoration(
                  border: Border.all(
                    color: isDestructive ? Colors.red[200]! : Colors.grey[200]!,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isPrimary
                          ? Colors.white.withOpacity(0.2)
                          : (isDestructive
                                ? Colors.red[100]
                                : theme.colorScheme.primary.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: isPrimary ? Colors.white : iconColor,
                      size: 24,
                    ),
                  ),
                  if (hasNotification && notificationCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: backgroundColor, width: 2),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          notificationCount > 99
                              ? '99+'
                              : notificationCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: subtitleColor),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: isPrimary
                    ? Colors.white.withOpacity(0.7)
                    : Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showQRCode(BuildContext context, GroupConnectionInfo groupInfo) {
  // Convert the group info to JSON string for the QR code
  final qrData = jsonEncode(groupInfo.toJson());

  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share Your Group',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Others can scan this QR code to join your group',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 250.0,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
