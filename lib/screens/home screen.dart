import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skripsie/providers/bluetooth_provider.dart';
import 'package:skripsie/screens/chat_page.dart';
import 'package:skripsie/screens/find_friend.dart';
import 'package:skripsie/screens/qr_scan_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothProvider>(
      builder: (context, bluetoothProvider, child) {
        return Scaffold(
          backgroundColor: Colors.grey[100],
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                children: [
                  // Header
                  Text(
                    'StickLite',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Central connection status indicator
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              bluetoothProvider.isConnected
                                  ? Icons.bluetooth_connected
                                  : Icons.bluetooth_disabled,
                              size: 80,
                              color: bluetoothProvider.isConnected
                                  ? Colors.blue
                                  : Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              bluetoothProvider.isConnected
                                  ? 'Connected'
                                  : 'Disconnected',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (bluetoothProvider.connectedDevice != null)
                              Text(
                                bluetoothProvider.connectedDevice!.name,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            if (bluetoothProvider.isConnected &&
                                bluetoothProvider.batteryPercentage !=
                                    null) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.battery_full, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${bluetoothProvider.batteryPercentage}%',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Action buttons
                  Column(
                    children: [
                      if (bluetoothProvider.isConnected)
                        _ActionButton(
                          icon: Icons.chat_bubble_outline,
                          label: 'Chat',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const ChatPage(),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 16),
                      if (bluetoothProvider.isConnected)
                        _ActionButton(
                          icon: Icons.person_add_outlined,
                          label: 'Find Friends',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const FindFriendPage(),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 16),
                      _ActionButton(
                        icon: bluetoothProvider.isConnected
                            ? Icons.bluetooth_disabled
                            : Icons.bluetooth_searching,
                        label: bluetoothProvider.isConnected
                            ? 'Disconnect'
                            : 'Connect Device',
                        onTap: () {
                          if (bluetoothProvider.isConnected) {
                            bluetoothProvider.disconnect();
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const QRScanPage(),
                              ),
                              (route) => false,
                            );
                          } else {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const QRScanPage(),
                              ),
                              (route) => false,
                            );
                          }
                        },
                        color: bluetoothProvider.isConnected
                            ? Colors.red
                            : Colors.blue,
                      ),
                    ],
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color ?? Colors.blue),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: color ?? Colors.blue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
