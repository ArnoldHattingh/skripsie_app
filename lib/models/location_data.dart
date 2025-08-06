import 'dart:math' as math;

class LocationData {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String userId;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'type': 'location',
      'userId': userId,
    };
  }

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userId: json['userId'] as String,
    );
  }

  double distanceTo(LocationData other) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    final lat1Rad = latitude * (math.pi / 180);
    final lat2Rad = other.latitude * (math.pi / 180);
    final deltaLat = (other.latitude - latitude) * (math.pi / 180);
    final deltaLon = (other.longitude - longitude) * (math.pi / 180);

    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * math.sin(deltaLon / 2) * math.sin(deltaLon / 2);
    final c = 2 * math.atan(math.sqrt(a) / math.sqrt(1 - a));

    return earthRadius * c;
  }

  double bearingTo(LocationData other) {
    final lat1Rad = latitude * (math.pi / 180);
    final lat2Rad = other.latitude * (math.pi / 180);
    final deltaLon = (other.longitude - longitude) * (math.pi / 180);

    final y = math.sin(deltaLon) * math.cos(lat2Rad);
    final x = math.cos(lat1Rad) * math.sin(lat2Rad) - 
              math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(deltaLon);

    var bearing = math.atan2(y, x) * 180 / math.pi;
    if (bearing < 0) bearing += 360;
    
    return bearing;
  }

  
} 