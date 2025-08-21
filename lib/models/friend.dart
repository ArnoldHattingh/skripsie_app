import 'dart:math' as math;

class Friend {
  String id;
  String name;
  DateTime lastSeen;
  double? latitude;
  double? longitude;
  final bool isMe;

  Friend({
    required this.id,
    required this.name,
    required this.lastSeen,
    required this.latitude,
    required this.longitude,
    required this.isMe,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'],
      name: json['name'],
      lastSeen: DateTime.parse(json['lastSeen']),
      latitude: json['latitude'],
      longitude: json['longitude'],
      isMe: json['isMe'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lastSeen': lastSeen.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'isMe': false,
    };
  }

  double? distanceTo(Friend other) {
    if (latitude == null ||
        longitude == null ||
        other.latitude == null ||
        other.longitude == null) {
      return null;
    }
    const double earthRadius = 6371000; // Earth's radius in meters

    final lat1Rad = latitude! * (math.pi / 180);
    final lat2Rad = other.latitude! * (math.pi / 180);
    final deltaLat = (other.latitude! - latitude!) * (math.pi / 180);
    final deltaLon = (other.longitude! - longitude!) * (math.pi / 180);

    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);
    final c = 2 * math.atan(math.sqrt(a) / math.sqrt(1 - a));

    return earthRadius * c;
  }

  double? bearingTo(Friend other) {
    if (latitude == null ||
        longitude == null ||
        other.latitude == null ||
        other.longitude == null) {
      return null;
    }
    final lat1Rad = latitude! * (math.pi / 180);
    final lat2Rad = other.latitude! * (math.pi / 180);
    final deltaLon = (other.longitude! - longitude!) * (math.pi / 180);

    final y = math.sin(deltaLon) * math.cos(lat2Rad);
    final x =
        math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(deltaLon);

    var bearing = math.atan2(y, x) * 180 / math.pi;
    if (bearing < 0) bearing += 360;

    return bearing;
  }
}
