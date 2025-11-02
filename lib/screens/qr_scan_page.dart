import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:skripsie/providers/bluetooth_provider.dart';
import 'package:skripsie/screens/device_selection_page.dart';

class QRScanPage extends StatefulWidget {
  const QRScanPage({super.key});
  @override
  State<QRScanPage> createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  final _controller = TextEditingController();
  bool _isProcessing = false;

  void _handleDeviceCode(String code) {
    if (_isProcessing) return;

    final trimmedCode = code.trim();
    if (trimmedCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a device code')),
      );
      return;
    }

    if (trimmedCode.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid device code - must be exactly 8 characters'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate that the code contains only valid characters (hex)
    if (!RegExp(r'^[0-9A-Fa-f]{8}$').hasMatch(trimmedCode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invalid device code - must contain only hexadecimal characters (0-9, A-F)',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final bluetoothProvider = Provider.of<BluetoothProvider>(context, listen: false);
      
      if (bluetoothProvider.generateUuidsFromCode(trimmedCode)) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const DeviceSelectionPage(),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error generating device UUIDs'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing device code: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showGenerateQrDialog() async {
    final textController = TextEditingController();
    String? enteredText = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter Information for QR Code'),
          content: TextField(
            controller: textController,
            autofocus: true,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Enter text or information...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(textController.text);
              },
              child: const Text('Generate QR Code'),
            ),
          ],
        );
      },
    );
    if (enteredText != null && enteredText.trim().isNotEmpty) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QRGeneratedDisplayPage(data: enteredText.trim()),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Connect to Device'),
          centerTitle: true,
          elevation: 0,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.background,
                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                      ),
                      child: Icon(
                        Icons.qr_code_scanner,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 40),
                    FilledButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () async {
                              final result = await Navigator.of(context)
                                  .push<String>(
                                    MaterialPageRoute(
                                      builder: (context) => const QRScannerPage(),
                                    ),
                                  );
                              if (result != null && mounted) {
                                _handleDeviceCode(result);
                              }
                            },
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Scan QR Code',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    // const SizedBox(height: 20),
                    // FilledButton.icon(
                    //   onPressed: _showGenerateQrDialog,
                    //   icon: const Icon(Icons.qr_code),
                    //   label: const Padding(
                    //     padding: EdgeInsets.all(16.0),
                    //     child: Text(
                    //       'Generate QR Code',
                    //       style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    //     ),
                    //   ),
                    //   style: FilledButton.styleFrom(
                    //     backgroundColor: Colors.white,
                    //     foregroundColor: Theme.of(context).colorScheme.primary,
                    //     shape: RoundedRectangleBorder(
                    //       borderRadius: BorderRadius.circular(16),
                    //       side: BorderSide(
                    //         color: Theme.of(context).colorScheme.primary,
                    //         width: 1.5
                    //       ),
                    //     ),
                    //     elevation: 0,
                    //   ),
                    // ),
                    const SizedBox(height: 40),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 40),
                    TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        labelText: 'Enter Device Code',
                        hintText: '8 character code',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        helperText: 'Enter exactly 8 hexadecimal characters (0-9, A-F)',
                        prefixIcon: Icon(
                          Icons.vpn_key_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      maxLength: 8,
                      textCapitalization: TextCapitalization.characters,
                      enabled: !_isProcessing,
                      onSubmitted: (_) => _handleDeviceCode(_controller.text),
                      style: const TextStyle(
                        fontSize: 16,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _handleDeviceCode(_controller.text),
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.connect_without_contact),
                      label: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          _isProcessing ? 'Connecting...' : 'Connect',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});
  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  bool _hasScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () async {
              await controller?.toggleFlash();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          QRView(
            key: qrKey,
            onQRViewCreated: (QRViewController controller) {
              this.controller = controller;
              controller.scannedDataStream.listen((scanData) {
                if (scanData.code != null && !_hasScanned) {
                  _hasScanned = true;
                  Navigator.of(context).pop(scanData.code);
                }
              });
            },
            overlay: QrScannerOverlayShape(
              borderColor: Theme.of(context).colorScheme.primary,
              borderRadius: 16,
              borderLength: 32,
              borderWidth: 12,
              cutOutSize: MediaQuery.of(context).size.width * 0.8,
            ),
          ),
          Positioned(
            bottom: 48,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                'Position QR code within the frame',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

///
/// Beautiful QR Code Sticker Display Page
///

class QRGeneratedDisplayPage extends StatelessWidget {
  final String data;
  const QRGeneratedDisplayPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final stickerWidth = MediaQuery.of(context).size.width * 0.86;
    final stickerHeight = stickerWidth * 1.18;

    return Scaffold(
      backgroundColor: const Color(0xFF181A35), // Matches blue/purple device background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Scan This QR Code',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Container(
          width: stickerWidth,
          height: stickerHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(38),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 22,
                offset: const Offset(0, 8),
                spreadRadius: 0.5,
              ),
            ],
            border: Border.all(
              color: Colors.grey.shade200,
              width: 2.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                
                Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xEEF1F2FC),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.indigo.withOpacity(0.10),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: QrImageView(
                              data: data,
                              version: QrVersions.auto,
                              size: stickerWidth * 0.54,
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF181A35),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xffe1e3ff),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SelectableText(
                              data,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 19,
                                color: Color(0xFF181A35),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3.5,
                                fontFamily: 'RobotoMono',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Logo at the bottom
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: Image.asset(
                        "lib/assets/Logo Design.png", // Make sure your logo PNG is at this location
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Friend Radar",
                          style: TextStyle(
                            color: Colors.indigo[900],
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Scan to connect your device",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13.2,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
