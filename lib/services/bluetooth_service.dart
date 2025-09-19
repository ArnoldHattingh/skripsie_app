import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:skripsie/models/group_connection_info.dart';
import 'dart:developer' as developer;

import 'package:skripsie/services/secure_codec.dart';

class BluetoothService {
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  // Connection state
  bool _isConnected = false;
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isDisposed = false;

  SecureCodec? _codec;
  final int _memberId =
      GroupConnectionInfo.generateMemberId(); // or load persisted
  Uint8List? _bootSalt; // 4B from provisioning or random
  // Device and connection management
  DiscoveredDevice? _connectedDevice;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  StreamSubscription<List<int>>? _messageSubscription;

  // Characteristic management
  QualifiedCharacteristic? _rxCharacteristic;
  QualifiedCharacteristic? _txCharacteristic;

  // Device discovery
  final List<DiscoveredDevice> _discoveredDevices = [];
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  Timer? _scanTimer;
  Timer? _locationTimer;

  // UUIDs
  Uuid? _serviceUuid;
  Uuid? _rxCharUuid;
  Uuid? _txCharUuid;

  // Callbacks
  VoidCallback? onConnectionStateChanged;
  Function(Map<String, dynamic>)? onMessageReceived;
  VoidCallback? onDevicesUpdated;
  Function(int sent, int total)? onSendProgress;
  Function(int received, int total)? onReceiveProgress;

  // Getters
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  bool get isConnecting => _isConnecting;
  DiscoveredDevice? get connectedDevice => _connectedDevice;
  List<DiscoveredDevice> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);
  Uuid? get serviceUuid => _serviceUuid;
  Uuid? get rxCharUuid => _rxCharUuid;
  Uuid? get txCharUuid => _txCharUuid;

  /// Generate UUIDs from device code
  bool generateUuidsFromCode(String deviceCode) {
    if (_isDisposed) return false;

    try {
      print('BluetoothService: Generating UUIDs from device code: $deviceCode');
      final trimmedCode = deviceCode.trim();

      // Validate device code
      if (trimmedCode.isEmpty || trimmedCode.length != 8) {
        print(
          'BluetoothService: Invalid device code length: ${trimmedCode.length}',
        );
        return false;
      }

      // Validate hex format
      if (!RegExp(r'^[0-9A-Fa-f]{8}$').hasMatch(trimmedCode)) {
        print(
          'BluetoothService: Invalid hex format for device code: $trimmedCode',
        );
        return false;
      }

      // Generate UUIDs with 8-4-4-4-12 layout
      _serviceUuid = Uuid.parse(
        "${trimmedCode.substring(0, 8)}-" // 8 chars
        "0000-" // 4 chars
        "0000-" // 4 chars
        "0000-" // fixed 4 chars
        "000000000000", // 12 chars
      );

      _rxCharUuid = Uuid.parse(
        "${trimmedCode.substring(0, 8)}-" // 8 chars
        "1000-" // 4 chars
        "0000-" // 4 chars
        "0000-" // fixed 4 chars
        "000000000000", // 12 chars
      );

      _txCharUuid = Uuid.parse(
        "${trimmedCode.substring(0, 8)}-" // 8 chars
        "2000-" // 4 chars
        "0000-" // 4 chars
        "0000-" // fixed 4 chars
        "000000000000", // 12 chars
      );

      print('BluetoothService: Generated UUIDs successfully');
      print('  Service UUID: $_serviceUuid');
      print('  RX Char UUID: $_rxCharUuid');
      print('  TX Char UUID: $_txCharUuid');

      return true;
    } catch (e) {
      print('BluetoothService: Error generating UUIDs: $e');
      developer.log('Error generating UUIDs: $e');
      return false;
    }
  }

  // Call this once when you load/receive the group info (from QR)
  void setGroupInfo(GroupConnectionInfo gci) {
    print('BluetoothService: Setting group info');
    _bootSalt ??= GroupConnectionInfo.generateBootSalt(); // <- now public
    _codec = SecureCodec(
      kEnc: gci.kEnc, // same for the whole group
      senderId: _memberId, // your local 32-bit id (persist!)
      initialSeq: 0,
      aeadAlg: 'chacha20',
      maxFrameBytes: 148, // more LoRa-friendly per fragment
    );
    print('BluetoothService: Group info set, codec initialized');
  }

  /// Start scanning for devices
  void startScan() {
    if (_isScanning || _serviceUuid == null || _isDisposed) {
      print(
        'BluetoothService: Cannot start scan - isScanning: $_isScanning, serviceUuid: $_serviceUuid, isDisposed: $_isDisposed',
      );
      return;
    }

    _discoveredDevices.clear();
    _isScanning = true;
    onDevicesUpdated?.call();

    print("BluetoothService: Starting scan for devices...");
    print("Service UUID: $_serviceUuid");
    print("RX Char UUID: $_rxCharUuid");
    print("TX Char UUID: $_txCharUuid");

    _scanSubscription = _ble
        .scanForDevices(withServices: [], scanMode: ScanMode.lowLatency)
        .listen(
          (device) {
            print(
              'BluetoothService: Discovered device: ${device.name} (${device.id})',
            );
            if (_discoveredDevices.indexWhere((d) => d.id == device.id) < 0) {
              _discoveredDevices.add(device);
              onDevicesUpdated?.call();
              print(
                'BluetoothService: Added device to list. Total devices: ${_discoveredDevices.length}',
              );
            }

            // Auto-connect to matching device
            final expectedName =
                "StickLite-${_serviceUuid.toString().substring(0, 8)}";
            print(
              'BluetoothService: Looking for device name: $expectedName, found: ${device.name}',
            );
            if (device.name == expectedName) {
              print('BluetoothService: Found matching device! Connecting...');
              stopScan();
              connectToDevice(device);
            }
          },
          onError: (e) {
            print('BluetoothService: Scan error: $e');
            developer.log('Scan error: $e');
            stopScan();
          },
        );

    // Restart scan every 5 seconds
    _scanTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      print("BluetoothService: Restarting scan for devices");
      developer.log("Restarting scan for devices");
      stopScan();
      startScan();
    });
  }

  /// Stop scanning for devices
  void stopScan() {
    print('BluetoothService: Stopping scan');
    _scanSubscription?.cancel();
    _scanTimer?.cancel();
    _isScanning = false;
    onDevicesUpdated?.call();
  }

  /// Connect to a specific device
  Future<bool> connectToDevice(DiscoveredDevice device) async {
    if (_isConnecting || _isDisposed) {
      print(
        'BluetoothService: Cannot connect - isConnecting: $_isConnecting, isDisposed: $_isDisposed',
      );
      return false;
    }

    print(
      'BluetoothService: Attempting to connect to device: ${device.name} (${device.id})',
    );
    _isConnecting = true;
    onConnectionStateChanged?.call();

    try {
      final connection = _ble
          .connectToDevice(
            id: device.id,
            connectionTimeout: const Duration(seconds: 5),
          )
          .asBroadcastStream();

      _connectionSubscription = connection.listen(
        (update) {
          print(
            'BluetoothService: Connection state update: ${update.connectionState}',
          );
          if (update.connectionState == DeviceConnectionState.connected) {
            print('BluetoothService: Successfully connected to device');
            _isConnected = true;
            _connectedDevice = device;
            _setupMessageHandling();
            _startLocationUpdates();
            onConnectionStateChanged?.call();
          } else if (update.connectionState ==
              DeviceConnectionState.disconnected) {
            print('BluetoothService: Device disconnected');
            _isConnected = false;
            _connectedDevice = null;
            _messageSubscription?.cancel();
            _messageSubscription = null;
            _locationTimer?.cancel();
            onConnectionStateChanged?.call();
          }
        },
        onError: (error) {
          print('BluetoothService: Connection error: $error');
          developer.log('Connection error: $error');
          _isConnected = false;
          _connectedDevice = null;
          onConnectionStateChanged?.call();
        },
      );

      await connection.first;
      print('BluetoothService: Connection established');
      return true;
    } catch (e) {
      print('BluetoothService: Failed to connect: $e');
      developer.log('Failed to connect: $e');
      _isConnecting = false;
      onConnectionStateChanged?.call();
      return false;
    }
  }

  /// Start periodic location updates
  void _startLocationUpdates() {
    print('BluetoothService: Starting location updates');
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      // This will need to be coordinated with the provider
      // For now, we'll leave this as a placeholder
      print('BluetoothService: Location update tick');
    });
  }

  /// Setup message handling after connection
  void _setupMessageHandling() {
    print('BluetoothService: Setting up message handling');
    if (_serviceUuid == null ||
        _rxCharUuid == null ||
        _txCharUuid == null ||
        _connectedDevice == null) {
      print(
        'BluetoothService: Cannot setup message handling - missing UUIDs or device',
      );
      return;
    }

    _rxCharacteristic = QualifiedCharacteristic(
      serviceId: _serviceUuid!,
      characteristicId: _rxCharUuid!,
      deviceId: _connectedDevice!.id,
    );

    _txCharacteristic = QualifiedCharacteristic(
      serviceId: _serviceUuid!,
      characteristicId: _txCharUuid!,
      deviceId: _connectedDevice!.id,
    );

    print('BluetoothService: Subscribing to TX characteristic');
    _messageSubscription = _ble
        .subscribeToCharacteristic(_txCharacteristic!)
        .listen(
          (data) {
            print('BluetoothService: Received data: ${data.length} bytes');
            if (_codec == null) {
              print('BluetoothService: No codec available for decryption');
              return;
            }

            // Process decryption in parallel without blocking the stream
            _processDecryptionAsync(Uint8List.fromList(data));
          },
          onError: (e) {
            print('BluetoothService: Subscription error: $e');
            developer.log('Subscription error: $e');
          },
        );
    print('BluetoothService: Message handling setup complete');
  }

  /// Process decryption asynchronously in parallel
  void _processDecryptionAsync(Uint8List data) async {
    try {
      final maybeJson = await _codec!.tryDecryptFrame(
        data,
        onNonJson: (type, flags, hop, senderId, seq, pt) {
          print(
            'BluetoothService: Received non-JSON frame - type: $type, senderId: $senderId, seq: $seq',
          );
          // Handle other types if you add them later (acks, etc.)
        },
        onFragProgress: (received, total, senderId, seq) {
          onReceiveProgress?.call(received, total);
        },
      );

      _codec!.sweepStaleFragments();

      if (maybeJson != null) {
        print(
          'BluetoothService: Successfully decrypted JSON message: $maybeJson',
        );
        onMessageReceived?.call(maybeJson);
      } else {
        print('BluetoothService: Decryption returned null');
      }
    } catch (e) {
      print('BluetoothService: Decryption error: $e');
      developer.log('Decryption error: $e');
    }
  }

  /// Send data
  Future<bool> sendData(Map<String, dynamic> json) async {
    print('BluetoothService: Attempting to send data: $json');
    if (!_isConnected ||
        _rxCharacteristic == null ||
        _isDisposed ||
        _codec == null) {
      print(
        'BluetoothService: Cannot send data - isConnected: $_isConnected, rxChar: $_rxCharacteristic, isDisposed: $_isDisposed, codec: $_codec',
      );
      return false;
    }
    try {
      print('BluetoothService: Encrypting JSON data');
      // Encrypt JSON map; may produce multiple frames if large
      final frames = await _codec!.encryptJson(json, type: MsgType.json);
      print('BluetoothService: Generated ${frames.length} frames');
      for (int i = 0; i < frames.length; i++) {
        final f = frames[i];
        print(
          'BluetoothService: Sending frame ${i + 1}/${frames.length} (${f.length} bytes)',
        );
        await _ble.writeCharacteristicWithoutResponse(
          _rxCharacteristic!,
          value: f,
        );
        onSendProgress?.call(i + 1, frames.length);
        // Increased pacing to help MCU/LoRa forward reliably
        await Future.delayed(const Duration(milliseconds: 50));
      }
      print('BluetoothService: All frames sent successfully');
      return true;
    } catch (e) {
      print('BluetoothService: Send error: $e');
      developer.log('Send error: $e');
      return false;
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    if (_isDisposed) return;

    print('BluetoothService: Disconnecting from device');
    try {
      _messageSubscription?.cancel();
      _connectionSubscription?.cancel();
      _locationTimer?.cancel();
      stopScan();

      _isConnected = false;
      _isConnecting = false;
      _connectedDevice = null;
      _rxCharacteristic = null;
      _txCharacteristic = null;

      onConnectionStateChanged?.call();
      print('BluetoothService: Disconnection complete');
    } catch (e) {
      print('BluetoothService: Error during disconnect: $e');
      developer.log('Error during disconnect: $e');
    }
  }

  void dispose() {
    print('BluetoothService: Disposing service');
    _isDisposed = true;

    // Cancel all subscriptions and timers
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    _locationTimer?.cancel();
    _scanSubscription?.cancel();
    _scanTimer?.cancel();

    // Clear all data
    _isConnected = false;
    _isConnecting = false;
    _connectedDevice = null;
    _rxCharacteristic = null;
    _txCharacteristic = null;
    _discoveredDevices.clear();
    print('BluetoothService: Service disposed');
  }
}
