import 'dart:async';
import 'dart:convert';
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
      final trimmedCode = deviceCode.trim();

      // Validate device code
      if (trimmedCode.isEmpty || trimmedCode.length != 8) {
        return false;
      }

      // Validate hex format
      if (!RegExp(r'^[0-9A-Fa-f]{8}$').hasMatch(trimmedCode)) {
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

      return true;
    } catch (e) {
      developer.log('Error generating UUIDs: $e');
      return false;
    }
  }

  // Call this once when you load/receive the group info (from QR)
  void setGroupInfo(GroupConnectionInfo gci) {
    _bootSalt ??= GroupConnectionInfo.generateBootSalt(); // <- now public
    _codec = SecureCodec(
      kEnc: gci.kEnc, // same for the whole group
      senderId: _memberId, // your local 32-bit id (persist!)
      initialSeq: 0,
      aeadAlg: 'chacha20',
      maxFrameBytes: 148, // more LoRa-friendly per fragment
    );
  }

  /// Start scanning for devices
  void startScan() {
    if (_isScanning || _serviceUuid == null || _isDisposed) {
      return;
    }

    _discoveredDevices.clear();
    _isScanning = true;
    onDevicesUpdated?.call();

    _scanSubscription = _ble
        .scanForDevices(withServices: [], scanMode: ScanMode.lowLatency)
        .listen(
          (device) {
            if (_discoveredDevices.indexWhere((d) => d.id == device.id) < 0) {
              _discoveredDevices.add(device);
              onDevicesUpdated?.call();
            }

            // Auto-connect to matching device
            final expectedName =
                "StickLite-${_serviceUuid.toString().substring(0, 8)}";
            if (device.name == expectedName) {
              stopScan();
              connectToDevice(device);
            }
          },
          onError: (e) {
            developer.log('Scan error: $e');
            stopScan();
          },
        );

    // Restart scan every 5 seconds
    _scanTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      developer.log("Restarting scan for devices");
      stopScan();
      startScan();
    });
  }

  /// Stop scanning for devices
  void stopScan() {
    _scanSubscription?.cancel();
    _scanTimer?.cancel();
    _isScanning = false;
    onDevicesUpdated?.call();
  }

  /// Connect to a specific device
  Future<bool> connectToDevice(DiscoveredDevice device) async {
    if (_isConnecting || _isDisposed) {
      return false;
    }

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
          if (update.connectionState == DeviceConnectionState.connected) {
            _isConnected = true;
            _connectedDevice = device;
            _setupMessageHandling();
            _startLocationUpdates();
            onConnectionStateChanged?.call();
          } else if (update.connectionState ==
              DeviceConnectionState.disconnected) {
            _isConnected = false;
            _connectedDevice = null;
            _messageSubscription?.cancel();
            _messageSubscription = null;
            _locationTimer?.cancel();
            onConnectionStateChanged?.call();
          }
        },
        onError: (error) {
          developer.log('Connection error: $error');
          _isConnected = false;
          _connectedDevice = null;
          onConnectionStateChanged?.call();
        },
      );

      await connection.first;
      return true;
    } catch (e) {
      developer.log('Failed to connect: $e');
      _isConnecting = false;
      onConnectionStateChanged?.call();
      return false;
    }
  }

  /// Start periodic location updates
  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      // This will need to be coordinated with the provider
      // For now, we'll leave this as a placeholder
    });
  }

  /// Setup message handling after connection
  void _setupMessageHandling() {
    if (_serviceUuid == null ||
        _rxCharUuid == null ||
        _txCharUuid == null ||
        _connectedDevice == null) {
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

    _messageSubscription = _ble
        .subscribeToCharacteristic(_txCharacteristic!)
        .listen(
          (data) {
            // Process decryption in parallel without blocking the stream
            _processDecryptionAsync(Uint8List.fromList(data));
          },
          onError: (e) {
            developer.log('Subscription error: $e');
          },
        );
  }

  /// Process decryption asynchronously in parallel
  void _processDecryptionAsync(Uint8List data) async {
    try {
      Map<String, dynamic>? maybeJson;

      if (_codec == null) {
        // No encryption codec set: attempt raw JSON parse
        maybeJson = _bytesToJson(data);
      } else {
        // Try decrypting first
        maybeJson = await _codec!.tryDecryptFrame(
          data,
          onNonJson: (type, flags, hop, senderId, seq, pt) {
            // Intentionally no plaintext logging for non-JSON types to reduce noise
          },
          onFragProgress: (received, total, senderId, seq) {
            onReceiveProgress?.call(received, total);
          },
        );

        // Fallback: if decrypt returned null, try parsing as raw JSON telemetry
        if (maybeJson == null) {
          final raw = _bytesToJson(data);
          if (raw != null) {
            maybeJson = raw;
          }
        }
      }

      if (_codec != null) {
        _codec!.sweepStaleFragments();
      }

      if (maybeJson != null) {
        developer.log('Decrypted JSON received: ${jsonEncode(maybeJson)}');
        onMessageReceived?.call(maybeJson);
      }
    } catch (e) {
      developer.log('Decryption error: $e');
    }
  }

  Map<String, dynamic>? _bytesToJson(Uint8List pt) {
    try {
      final decoded = utf8.decode(pt);
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      return json;
    } catch (e) {
      developer.log('JSON parse error: $e');
      return null;
    }
  }

  /// Send data
  Future<bool> sendData(
    Map<String, dynamic> json, {
    bool encrypt = true,
    bool sendRaw = false,
  }) async {
    if (!_isConnected ||
        _rxCharacteristic == null ||
        _isDisposed ||
        (encrypt && _codec == null)) {
      return false;
    }
    try {
      final jsonStr = jsonEncode(json);
      developer.log('Sending JSON plaintext: $jsonStr');

      // Encrypt JSON map; may produce multiple frames if large
      final frames = encrypt
          ? await _codec!.encryptJson(json, type: MsgType.json)
          : [Uint8List.fromList(utf8.encode(jsonStr))];

      if (sendRaw) {
        await _ble.writeCharacteristicWithoutResponse(
          _rxCharacteristic!,
          value: frames[0],
        );
        onSendProgress?.call(1, 1);
        return true;
      }

      for (int i = 0; i < frames.length; i++) {
        final f = frames[i];
        await _ble.writeCharacteristicWithoutResponse(
          _rxCharacteristic!,
          value: f,
        );
        onSendProgress?.call(i + 1, frames.length);
        // Increased pacing to help MCU/LoRa forward reliably
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return true;
    } catch (e) {
      developer.log('Send error: $e');
      return false;
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    if (_isDisposed) return;

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
    } catch (e) {
      developer.log('Error during disconnect: $e');
    }
  }

  void dispose() {
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
  }
}
