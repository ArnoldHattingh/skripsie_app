import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skripsie/providers/bluetooth_provider.dart';
import 'package:skripsie/screens/chat_page.dart';
import 'package:skripsie/screens/home%20screen.dart';

class DeviceSelectionPage extends StatefulWidget {
  const DeviceSelectionPage({super.key});

  @override
  State<DeviceSelectionPage> createState() => _DeviceSelectionPageState();
}

class _DeviceSelectionPageState extends State<DeviceSelectionPage> {
  @override
  void initState() {
    super.initState();
    // Start scanning when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bluetoothProvider = Provider.of<BluetoothProvider>(
        context,
        listen: false,
      );
      bluetoothProvider.setOnConnectedCallback(() {
        bluetoothProvider.stopScan();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      });
      bluetoothProvider.startScan();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothProvider>(
      builder: (context, bluetoothProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text("Connecting"),
            elevation: 0,
            leading: Navigator.canPop(context)
                ? IconButton(
                    onPressed: () {
                      final bluetoothProvider = Provider.of<BluetoothProvider>(
                        context,
                        listen: false,
                      );
                      bluetoothProvider.stopScan();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.arrow_back),
                  )
                : null,
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withOpacity(0.2),
                  ),
                  child: Icon(
                    Icons.bluetooth_searching,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  "Searching for your device",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  "Please make sure your device is turned on\nand within range",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (bluetoothProvider.isConnecting) ...[
                  const SizedBox(height: 24),
                  Text(
                    "Connecting...",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
