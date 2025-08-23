import 'dart:async';
import 'dart:developer' as developer;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:skripsie/models/chat_message.dart';
import 'package:skripsie/models/friend.dart';
import 'package:skripsie/models/group_connection_info.dart';
import 'package:skripsie/services/bluetooth_service.dart';

class BluetoothProvider extends ChangeNotifier {
  late final BluetoothService _bluetoothService;

  // Navigation callback
  VoidCallback? _onConnected;

  //Getters
  bool get isConnected => _bluetoothService.isConnected;
  bool get isScanning => _bluetoothService.isScanning;
  bool get isConnecting => _bluetoothService.isConnecting;
  DiscoveredDevice? get connectedDevice => _bluetoothService.connectedDevice;
  int? get batteryPercentage => _bluetoothService.batteryPercentage;
  bool get isSending => _isSending;
  List<ChatMessage>? get messages =>
      _messages != null ? List.unmodifiable(_messages!) : null;
  List<Friend>? get friends => _friends;
  GroupConnectionInfo? get groupConnectionInfo => _groupConnectionInfo;

  // State
  bool _isSending = false;
  bool _isDisposed = false;
  List<ChatMessage>? _messages;
  List<Friend>? _friends;
  GroupConnectionInfo? _groupConnectionInfo;

  /// Safely notify listeners only if not disposed
  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  BluetoothProvider({double? latitude, double? longitude}) {
    _bluetoothService = BluetoothService();
    _setupBluetoothServiceListeners();

    _friends = [
      Friend(
        id: "1",
        name: "Friend 1",
        lastSeen: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        isMe: true,
      ),
    ];
  }

  void _setupBluetoothServiceListeners() {
    _bluetoothService.onConnectionStateChanged = () {
      if (_bluetoothService.isConnected && _onConnected != null) {
        _onConnected!();
      }
      _safeNotifyListeners();
    };

    _bluetoothService.onMessageReceived = (Map<String, dynamic> data) {
      _handleReceivedMessage(data);
    };

    _bluetoothService.onDevicesUpdated = () {
      _safeNotifyListeners();
    };
  }

  void _handleReceivedMessage(Map<String, dynamic> jsonData) {
    try {
      if (jsonData['type'] == 'location') {
        // Handle location data
        final friend = Friend.fromJson(jsonData);
        final existingIndex =
            _friends?.indexWhere((f) => f.id == friend.id) ?? -1;
        if (existingIndex == -1) {
          _friends?.add(friend);
        } else {
          _friends![existingIndex] = friend;
        }
        developer.log(
          'Received friend location: ${friend.latitude}, ${friend.longitude}',
        );
      } else if (jsonData['text'] != null) {
        jsonData['isMe'] = false;
        final message = ChatMessage.fromJson(jsonData);
        _messages ??= [];
        _messages!.add(message);
      }

      _safeNotifyListeners();
    } catch (e) {
      developer.log('Error handling received message: $e');
    }
  }

  /// Update the myLocation field without creating a new instance
  void updateMyLocation(double? latitude, double? longitude) {
    _friends?.firstWhereOrNull((friend) => friend.isMe)?.latitude = latitude;
    _friends?.firstWhereOrNull((friend) => friend.isMe)?.longitude = longitude;
    _friends?.firstWhereOrNull((friend) => friend.isMe)?.lastSeen =
        DateTime.now();
    _safeNotifyListeners();
    print("🌍 My Location Updated: $latitude, $longitude");
  }

  void updateMyName(String name) {
    _friends?.firstWhereOrNull((friend) => friend.isMe)?.name = name;
    _safeNotifyListeners();
  }

  void updateGroupConnectionInfo(GroupConnectionInfo groupConnectionInfo) {
    _groupConnectionInfo = groupConnectionInfo;
    _safeNotifyListeners();
  }

  /// Set navigation callback for when connection is established
  void setOnConnectedCallback(VoidCallback callback) {
    _onConnected = callback;
  }

  /// Generate UUIDs from device code
  bool generateUuidsFromCode(String deviceCode) {
    if (_isDisposed) return false;
    final result = _bluetoothService.generateUuidsFromCode(deviceCode);
    if (result) {
      _safeNotifyListeners();
    }
    return result;
  }

  /// Start scanning for devices
  void startScan() {
    _bluetoothService.startScan();
  }

  /// Stop scanning for devices
  void stopScan() {
    _bluetoothService.stopScan();
  }

  /// Connect to a specific device
  Future<bool> connectToDevice(DiscoveredDevice device) async {
    if (_isDisposed) return false;
    return await _bluetoothService.connectToDevice(device);
  }

  /// Send a message
  Future<bool> sendMessage(String text) async {
    if (text.trim().isEmpty ||
        !_bluetoothService.isConnected ||
        _isSending ||
        _isDisposed) {
      return false;
    }

    _isSending = true;
    _safeNotifyListeners();

    final message = ChatMessage(
      text: text.trim(),
      isMe: true,
      timestamp: DateTime.now(),
      userName:
          _friends?.firstWhereOrNull((friend) => friend.isMe)?.name ??
          "Unknown",
    );

    try {
      final success = await _bluetoothService.sendData(message.toJson());

      if (success) {
        _messages ??= [];
        _messages!.add(message);
      }

      _isSending = false;
      _safeNotifyListeners();
      return success;
    } catch (e) {
      developer.log('Send error: $e');
      _isSending = false;
      _safeNotifyListeners();
      return false;
    }
  }

  Future<bool> sendLocationData(Map<String, dynamic> locationData) async {
    if (!_bluetoothService.isConnected || _isSending || _isDisposed) {
      return false;
    }

    _isSending = true;
    _safeNotifyListeners();

    try {
      final success = await _bluetoothService.sendData(locationData);
      _isSending = false;
      _safeNotifyListeners();
      return success;
    } catch (e) {
      developer.log('Send location error: $e');
      _isSending = false;
      _safeNotifyListeners();
      return false;
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    if (_isDisposed) return;

    try {
      await _bluetoothService.disconnect();
      _messages?.clear();
      _messages = null;
      _safeNotifyListeners();
    } catch (e) {
      developer.log('Error during disconnect: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _bluetoothService.dispose();
    _messages?.clear();
    _messages = null;
    super.dispose();
  }
}
