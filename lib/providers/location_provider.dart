import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:location/location.dart' as location_package;
import 'package:skripsie/models/friend.dart';

class LocationProvider extends ChangeNotifier {
  final location_package.Location _location = location_package.Location();

  // Location state
  bool _isLocationEnabled = false;
  bool _isLocationPermissionGranted = false;
  bool _isLocationServiceEnabled = false;
  bool _isSharingLocation = false;

  // Current location
  Friend? _currentLocation;
  StreamSubscription<location_package.LocationData>? _locationSubscription;

  LocationProvider() {
    initializeLocation();
  }

  // Getters
  bool get isLocationEnabled => _isLocationEnabled;
  bool get isLocationPermissionGranted => _isLocationPermissionGranted;
  bool get isLocationServiceEnabled => _isLocationServiceEnabled;
  bool get isSharingLocation => _isSharingLocation;
  Friend? get currentLocation => _currentLocation;

  // Distance and direction to friend
  double? distanceToFriend(Friend? friendLocation) {
    if (_currentLocation == null || friendLocation == null) return null;
    return _currentLocation!.distanceTo(friendLocation);
  }

  double? bearingToFriend(Friend? friendLocation) {
    if (_currentLocation == null || friendLocation == null) return null;
    return _currentLocation!.bearingTo(friendLocation);
  }

  /// Initialize location services
  Future<bool> initializeLocation() async {
    try {
      // Check if location service is enabled
      _isLocationServiceEnabled = await _location.serviceEnabled();
      if (!_isLocationServiceEnabled) {
        _isLocationServiceEnabled = await _location.requestService();
        if (!_isLocationServiceEnabled) {
          developer.log('Location service not enabled');
          return false;
        }
      }

      // Check location permission
      location_package.PermissionStatus permissionStatus = await _location
          .hasPermission();
      if (permissionStatus == location_package.PermissionStatus.denied) {
        permissionStatus = await _location.requestPermission();
        if (permissionStatus != location_package.PermissionStatus.granted) {
          developer.log('Location permission denied');
          return false;
        }
      }

      _isLocationPermissionGranted = true;
      _isLocationEnabled = true;

      // Start location updates
      await startLocationSharing();

      return true;
    } catch (e) {
      developer.log('Error initializing location: $e');
      return false;
    }
  }

  Future<void> startLocationSharing() async {
    if (!_isSharingLocation) {
      _isSharingLocation = true;

      // Configure location settings
      await _location.changeSettings(
        accuracy: location_package.LocationAccuracy.high,
        interval: 5000, // Update every 5 seconds
      );

      // Subscribe to location updates
      _locationSubscription = _location.onLocationChanged.listen(
        (location_package.LocationData locationData) {
          _currentLocation = Friend(
            id: "1",
            name: "Friend 1",
            lastSeen: DateTime.now(),
            latitude: locationData.latitude ?? 0,
            longitude: locationData.longitude ?? 0,
            isMe: true,
          );
          notifyListeners();
        },
        onError: (error) {
          developer.log('Error getting location updates: $error');
        },
      );
    }
  }

  void stopLocationSharing() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _isSharingLocation = false;
    notifyListeners();
  }

  String getDirectionString(Friend? friendLocation) {
    if (bearingToFriend(friendLocation) == null) return 'Unknown';

    final bearing = bearingToFriend(friendLocation)!;
    if (bearing >= 337.5 || bearing < 22.5) return 'North';
    if (bearing >= 22.5 && bearing < 67.5) return 'Northeast';
    if (bearing >= 67.5 && bearing < 112.5) return 'East';
    if (bearing >= 112.5 && bearing < 157.5) return 'Southeast';
    if (bearing >= 157.5 && bearing < 202.5) return 'South';
    if (bearing >= 202.5 && bearing < 247.5) return 'Southwest';
    if (bearing >= 247.5 && bearing < 292.5) return 'West';
    if (bearing >= 292.5 && bearing < 337.5) return 'Northwest';

    return 'Unknown';
  }

  /// Get distance string (meters, kilometers)
  String getDistanceString(Friend? friendLocation) {
    if (distanceToFriend(friendLocation) == null) return 'Unknown';

    final distance = distanceToFriend(friendLocation)!;
    if (distance < 1000) {
      return '${distance.toInt()}m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    }
  }

  @override
  void dispose() {
    stopLocationSharing();
    super.dispose();
  }
}
