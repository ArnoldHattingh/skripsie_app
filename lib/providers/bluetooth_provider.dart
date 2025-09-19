import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';
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

  // Location sharing timer
  Timer? _locationTimer;
  bool _hasInitialLocationSent = false;

  // Friend cleanup timer
  Timer? _friendCleanupTimer;

  //Getters
  bool get isConnected => _bluetoothService.isConnected;
  bool get isScanning => _bluetoothService.isScanning;
  bool get isConnecting => _bluetoothService.isConnecting;
  DiscoveredDevice? get connectedDevice => _bluetoothService.connectedDevice;
  int? get batteryPercentage => _batteryPercentage;
  bool get isSending => _isSending;
  int? get sendProgressSent => _sendProgressSent;
  int? get sendProgressTotal => _sendProgressTotal;
  int? get recvProgressReceived => _recvProgressReceived;
  int? get recvProgressTotal => _recvProgressTotal;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<Friend>? get friends => _friends;
  GroupConnectionInfo? get groupConnectionInfo => _groupConnectionInfo;
  int get unreadMessageCount => _unreadMessageCount;

  // State
  bool _isSending = false;
  bool _isDisposed = false;
  final List<ChatMessage> _messages = [];
  List<Friend>? _friends;
  GroupConnectionInfo? _groupConnectionInfo;
  int? _batteryPercentage;
  int _unreadMessageCount = 0;
  int? _sendProgressSent;
  int? _sendProgressTotal;
  int? _recvProgressReceived;
  int? _recvProgressTotal;

  /// Safely notify listeners only if not disposed
  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  BluetoothProvider({double? latitude, double? longitude}) {
    _bluetoothService = BluetoothService();
    _setupBluetoothServiceListeners();

    final random = Random();
    final randomId = random.nextInt(1000000000).toString();

    _friends = [
      Friend(
        id: randomId,
        name: "Friend 1",
        lastSeen: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        isMe: true,
      ),
    ];

    _startFriendCleanupTimer();
  }

  void _setupBluetoothServiceListeners() {
    _bluetoothService.onConnectionStateChanged = () {
      if (_bluetoothService.isConnected && _onConnected != null) {
        _onConnected!();
      } else {
        // Stop location timer when disconnected
        _stopLocationTimer();
        _hasInitialLocationSent = false;
      }
      _safeNotifyListeners();
    };

    _bluetoothService.onMessageReceived = (Map<String, dynamic> data) {
      _handleReceivedMessage(data);
    };

    _bluetoothService.onDevicesUpdated = () {
      _safeNotifyListeners();
    };

    _bluetoothService.onSendProgress = (sent, total) {
      _sendProgressSent = sent;
      _sendProgressTotal = total;
      if (sent == total) {
        _sendProgressSent = null;
        _sendProgressTotal = null;
      }
      _safeNotifyListeners();
    };

    _bluetoothService.onReceiveProgress = (received, total) {
      _recvProgressReceived = received;
      _recvProgressTotal = total;
      if (received == total) {
        _recvProgressReceived = null;
        _recvProgressTotal = null;
      }
      _safeNotifyListeners();
    };
  }

  void _sendInitialLocation() {
    if (_hasInitialLocationSent || _isDisposed || _groupConnectionInfo == null)
      return;

    final myFriend = _friends?.firstWhereOrNull((friend) => friend.isMe);
    if (myFriend?.latitude != null && myFriend?.longitude != null) {
      final locationData = myFriend!.toJson();
      sendData(locationData);
      _hasInitialLocationSent = true;
      developer.log('Initial location sent after joining group');
    }
  }

  void _startLocationTimer() {
    _stopLocationTimer(); // Ensure no duplicate timers

    _locationTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_isDisposed ||
          !_bluetoothService.isConnected ||
          _groupConnectionInfo == null) {
        timer.cancel();
        return;
      }

      final myFriend = _friends?.firstWhereOrNull((friend) => friend.isMe);
      if (myFriend?.latitude != null && myFriend?.longitude != null) {
        final locationData = myFriend!.toJson();
        sendData(locationData);
        developer.log('Periodic location update sent');
      }
    });
  }

  void _stopLocationTimer() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  void _startFriendCleanupTimer() {
    _friendCleanupTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      _cleanupInactiveFriends();
    });
  }

  void _stopFriendCleanupTimer() {
    _friendCleanupTimer?.cancel();
    _friendCleanupTimer = null;
  }

  void _cleanupInactiveFriends() {
    if (_friends == null) return;

    final now = DateTime.now();
    final inactiveThreshold = const Duration(minutes: 5);

    final initialCount = _friends!.length;

    _friends!.removeWhere((friend) {
      // Don't remove the user themselves
      if (friend.isMe) return false;

      // Remove if friend hasn't been seen in 5 minutes
      return now.difference(friend.lastSeen) > inactiveThreshold;
    });

    // Notify listeners if any friends were removed
    if (_friends!.length != initialCount) {
      developer.log(
        'Removed inactive friends. Count: ${initialCount - _friends!.length}',
      );
      _safeNotifyListeners();
    }
  }

  void _handleReceivedMessage(Map<String, dynamic> jsonData) {
    try {
      if (jsonData['latitude'] != null) {
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
        // Check if this is a location request message
        if (jsonData['text'] == 'LOCATION_REQUEST' &&
            jsonData['messageType'] == 'location_request') {
          _handleLocationRequest(jsonData);
        } else {
          jsonData['isMe'] = false;
          final message = ChatMessage.fromJson(jsonData);
          _messages.add(message);
          _unreadMessageCount++; // Increment unread count for received messages
        }
      } else if ((jsonData['messageType'] == 'image_bw' || jsonData['messageType'] == 'img_bw') && jsonData['image_bw'] != null) {
        // Handle low-res image message
        jsonData['isMe'] = false; // incoming => mark as not me
        final message = ChatMessage.fromJson(jsonData);
        _messages.add(message);
        _unreadMessageCount++;
      } else if (jsonData['battery'] != null) {
        _batteryPercentage = jsonData['battery'];
      }

      _safeNotifyListeners();
    } catch (e) {
      developer.log('Error handling received message: $e');
    }
  }

  void _handleLocationRequest(Map<String, dynamic> requestData) {
    developer.log('Received location request from ${requestData['userName']}');

    // Send current location back to the requester
    final myFriend = _friends?.firstWhereOrNull((friend) => friend.isMe);
    if (myFriend?.latitude != null && myFriend?.longitude != null) {
      final locationData = myFriend!.toJson();
      sendData(locationData);
      developer.log('Sent location in response to request');
    }
  }

  /// Request location update from a specific friend
  Future<bool> requestLocationUpdate(Friend friend) async {
    if (friend.isMe ||
        !_bluetoothService.isConnected ||
        _isSending ||
        _isDisposed) {
      developer.log('Cannot request location: invalid conditions');
      return false;
    }

    _isSending = true;
    _safeNotifyListeners();

    final myFriend = _friends?.firstWhereOrNull((f) => f.isMe);
    final requestMessage = {
      'text': 'LOCATION_REQUEST',
      'messageType': 'location_request',
      'isMe': true,
      'timestamp': DateTime.now().toIso8601String(),
      'userName': myFriend?.name ?? 'Unknown',
      'requestedFriendId': friend.id,
      'requestedFriendName': friend.name,
    };

    try {
      final success = await _bluetoothService.sendData(requestMessage);

      if (success) {
        developer.log('Location request sent to ${friend.name}');
      } else {
        developer.log('Failed to send location request to ${friend.name}');
      }

      _isSending = false;
      _safeNotifyListeners();
      return success;
    } catch (e) {
      developer.log('Error sending location request: $e');
      _isSending = false;
      _safeNotifyListeners();
      return false;
    }
  }

  /// Update the myLocation field without creating a new instance
  void updateMyLocation(double? latitude, double? longitude) {
    _friends?.firstWhereOrNull((friend) => friend.isMe)?.latitude = latitude;
    _friends?.firstWhereOrNull((friend) => friend.isMe)?.longitude = longitude;
    _friends?.firstWhereOrNull((friend) => friend.isMe)?.lastSeen =
        DateTime.now();
    _safeNotifyListeners();

    // If connected, in a group and haven't sent initial location, send it now
    if (_bluetoothService.isConnected &&
        _groupConnectionInfo != null &&
        !_hasInitialLocationSent) {
      _sendInitialLocation();
    }
  }

  void updateMyName(String name) {
    _friends?.firstWhereOrNull((friend) => friend.isMe)?.name = name;
    _safeNotifyListeners();
  }

  void updateGroupConnectionInfo(GroupConnectionInfo groupConnectionInfo) {
    _groupConnectionInfo = groupConnectionInfo;
    _bluetoothService.setGroupInfo(groupConnectionInfo);
    _safeNotifyListeners();

    // Send initial location when joining group
    if (_bluetoothService.isConnected && !_hasInitialLocationSent) {
      _sendInitialLocation();
      // Start location timer when joining group
      _startLocationTimer();
    }
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
      isMe: true,
      timestamp: DateTime.now(),
      userName:
          _friends?.firstWhereOrNull((friend) => friend.isMe)?.name ??
          "Unknown",
      messageType: 'text',
      text: text.trim(),
    );

    try {
      final success = await _bluetoothService.sendData(message.toJson());

      if (success) {
        _messages.add(message);
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

  Future<bool> sendData(Map<String, dynamic> sendData) async {
    if (!_bluetoothService.isConnected || _isSending || _isDisposed) {
      return false;
    }

    _isSending = true;
    _safeNotifyListeners();

    try {
      final success = await _bluetoothService.sendData(sendData);
      _isSending = false;
      _safeNotifyListeners();
      return success;
    } catch (e) {
      developer.log('Send data error: $e');
      _isSending = false;
      _safeNotifyListeners();
      return false;
    }
  }

  /// Mark all messages as read (reset unread count)
  void markMessagesAsRead() {
    _unreadMessageCount = 0;
    _safeNotifyListeners();
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    if (_isDisposed) return;

    try {
      _stopLocationTimer();
      _hasInitialLocationSent = false;
      await _bluetoothService.disconnect();
      _messages.clear();
      _unreadMessageCount = 0; // Reset unread count on disconnect
      _safeNotifyListeners();
    } catch (e) {
      developer.log('Error during disconnect: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopLocationTimer();
    _stopFriendCleanupTimer();
    _bluetoothService.dispose();
    _messages.clear();
    _unreadMessageCount = 0;
    super.dispose();
  }
}
