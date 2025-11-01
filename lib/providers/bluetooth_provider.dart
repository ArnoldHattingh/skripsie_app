import 'dart:async';
import 'dart:convert';
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
  bool get isRssiScanning => _isRssiScanning;
  Map<String, dynamic>? get rssiScanResults => _rssiScanResults;

  // State
  bool _isSending = false;
  bool _isDisposed = false;
  bool _isRssiScanning = false;
  Map<String, dynamic>? _rssiScanResults;
  final List<ChatMessage> _messages = [];
  List<Friend>? _friends;
  GroupConnectionInfo? _groupConnectionInfo;
  int? _batteryPercentage;
  int _unreadMessageCount = 0;
  int? _sendProgressSent;
  int? _sendProgressTotal;
  int? _recvProgressReceived;
  int? _recvProgressTotal;
  Map<String, dynamic>? _pendingLoraRx; // holds latest LoRa RX meta for next text message

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
    if (_hasInitialLocationSent ||
        _isDisposed ||
        _groupConnectionInfo == null) {
      return;
    }

    final myFriend = _friends?.firstWhereOrNull((friend) => friend.isMe);
    if (myFriend?.latitude != null && myFriend?.longitude != null) {
      final locationData = myFriend!.toJson();
      sendData(locationData);
      _hasInitialLocationSent = true;
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
        // reduced routine logging for friend location updates
      } else if (jsonData['text'] != null) {
        // Check if this is a location request message
        if (jsonData['text'] == 'LOCATION_REQUEST' &&
            jsonData['messageType'] == 'location_request') {
          _handleLocationRequest(jsonData);
        } else {
          // If we have pending loraRx meta from partial chunks, append it to the text
          if (_pendingLoraRx != null) {
            final rssi = _pendingLoraRx!['rssi'];
            final snr = _pendingLoraRx!['snr'];
            final len = _pendingLoraRx!['len'];
            final parts = <String>[];
            if (rssi != null) parts.add('RSSI $rssi');
            if (snr != null) parts.add('SNR $snr');
            if (len != null) parts.add('len $len');
            if (parts.isNotEmpty) {
              jsonData['text'] = '${jsonData['text']} (${parts.join(', ')})';
            }
            _pendingLoraRx = null; // consume after use
          }
          jsonData['isMe'] = false;
          final message = ChatMessage.fromJson(jsonData);
          _messages.add(message);
          _unreadMessageCount++; // Increment unread count for received messages
        }
      } else if (jsonData['messageType'] == 'image_2bpp' &&
          jsonData['image_2bpp'] != null) {
        // Handle 2-bpp grayscale image message
        jsonData['isMe'] = false;
        final message = ChatMessage.fromJson(jsonData);
        _messages.add(message);
        _unreadMessageCount++;
      } else if (jsonData['battery'] != null) {
        _batteryPercentage = jsonData['battery'];
      } else if (jsonData['t'] == 'loraRx') {
        // Buffer latest LoRa RX meta to be shown with the next full text chat message
        _pendingLoraRx = {
          'rssi': jsonData['rssi'],
          'snr': jsonData['snr'],
          'len': jsonData['len'],
        };
        // reduced routine logging for LoRa RX meta buffering
      } else if (jsonData['t'] == 'rssi') {
        // Handle RSSI scan results
        _rssiScanResults = jsonData;
        _isRssiScanning = false;
        // reduced routine logging for RSSI scan results
      }

      _safeNotifyListeners();
    } catch (e) {
      developer.log('Error handling received message: $e');
    }
  }

  void _handleLocationRequest(Map<String, dynamic> requestData) {
    // reduced routine logging for received location request

    // Send current location back to the requester
    final myFriend = _friends?.firstWhereOrNull((friend) => friend.isMe);
    if (myFriend?.latitude != null && myFriend?.longitude != null) {
      final locationData = myFriend!.toJson();
      sendData(locationData);
      // reduced routine logging for sent location response
    }
  }

  /// Start RSSI scan with provided parameters
  Future<bool> startRssiScan(Map<String, dynamic> scanParams) async {
    if (!_bluetoothService.isConnected || _isSending || _isDisposed || _isRssiScanning) {
      return false;
    }

    _isRssiScanning = true;
    _rssiScanResults = null; // Clear previous results
    _safeNotifyListeners();

    try {
      final success = await _bluetoothService.sendData(
        scanParams,
        sendRaw: true,
        encrypt: false,
      );

      if (!success) {
        _isRssiScanning = false;
        _safeNotifyListeners();
      }

      return success;
    } catch (e) {
      developer.log('Error starting RSSI scan: $e');
      _isRssiScanning = false;
      _safeNotifyListeners();
      return false;
    }
  }

  /// Request location update from a specific friend
  Future<bool> requestLocationUpdate(Friend friend) async {
    if (friend.isMe ||
        !_bluetoothService.isConnected ||
        _isSending ||
        _isDisposed) {
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

      // reduced routine logging for location request outcome

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
    _bluetoothService.sendData(
      {
        "messageType": "loraConfiguration",
        "freq":
            groupConnectionInfo.centerFrequencyHz /
            1000000.0, // Convert Hz to MHz
        "bw_khz": groupConnectionInfo.bandwidthHz / 1000, // Convert Hz to kHz
        "sf": groupConnectionInfo.spreadingFactor,
        "syncWord":
            "0x${groupConnectionInfo.syncWord.toRadixString(16).padLeft(4, '0').toUpperCase()}",
      },
      sendRaw: true,
      encrypt: false,
    );
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

  /// Capture already-prepared 2-bpp image bytes and send as a chat message.
  /// Adds the message locally on success.
  Future<bool> sendImage2bpp({
    required int width,
    required int height,
    required List<int> bytes,
  }) async {
    if (!_bluetoothService.isConnected || _isSending || _isDisposed) {
      return false;
    }

    _isSending = true;
    _safeNotifyListeners();

    final me = _friends?.firstWhereOrNull((f) => f.isMe);
    final b64 = base64Encode(bytes);

    final message = ChatMessage(
      isMe: true,
      timestamp: DateTime.now(),
      userName: me?.name ?? 'Unknown',
      messageType: 'image_2bpp',
      image2bpp: Image2bpp(width: width, height: height, dataB64: b64),
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
      developer.log('Send image_2bpp error: $e');
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
