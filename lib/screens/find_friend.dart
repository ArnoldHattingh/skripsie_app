import 'dart:async';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:provider/provider.dart';
import 'package:skripsie/models/friend.dart';
import 'package:skripsie/providers/bluetooth_provider.dart';
import 'package:skripsie/providers/location_provider.dart';

class FindFriendPage extends StatefulWidget {
  const FindFriendPage({super.key, required this.friendId});
  final String friendId;

  @override
  State<FindFriendPage> createState() => _FindFriendPageState();
}

class _FindFriendPageState extends State<FindFriendPage> {
  double _direction = 0;
  bool _hasCompass = false;
  Timer? _locationRequestTimer;
  DateTime? _lastLocationUpdate;

  @override
  void initState() {
    super.initState();
    _checkCompass();
    _startLocationUpdateTimer();
  }

  @override
  void dispose() {
    _locationRequestTimer?.cancel();
    super.dispose();
  }

  void _checkCompass() async {
    _hasCompass = FlutterCompass.events != null;
    if (mounted) setState(() {});
  }

  void _startLocationUpdateTimer() {
    _locationRequestTimer?.cancel();
    _locationRequestTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final bluetoothProvider = Provider.of<BluetoothProvider>(
        context,
        listen: false,
      );
      final locationProvider = Provider.of<LocationProvider>(
        context,
        listen: false,
      );
      final friend = bluetoothProvider.friends?.firstWhereOrNull(
        (f) => f.id == widget.friendId,
      );

      if (friend != null && !friend.isMe) {
        final distance = locationProvider.distanceToFriend(friend);
        final timeSinceLastUpdate = DateTime.now()
            .difference(friend.lastSeen)
            .inSeconds;

        // Calculate refresh interval based on distance (5-30 seconds)
        int refreshInterval;
        if (distance != null) {
          if (distance < 20) {
            refreshInterval = 5; // Very close - update every 5 seconds
          } else if (distance < 200) {
            refreshInterval = 10; // Close - update every 10 seconds
          } else if (distance < 500) {
            refreshInterval = 15; // Medium distance - update every 15 seconds
          } else if (distance < 1000) {
            refreshInterval = 20; // Far - update every 20 seconds
          } else {
            refreshInterval = 30; // Very far - update every 30 seconds
          }
        } else {
          refreshInterval = 15; // Default if distance is unknown
        }

        // Add randomness to prevent radio band conflicts (±1-3 seconds)
        final random = Random();
        final randomDelay = refreshInterval + random.nextInt(3) + 1;

        // Request update if enough time has passed
        if (timeSinceLastUpdate >= randomDelay) {
          bluetoothProvider.requestLocationUpdate(friend);
          _lastLocationUpdate = DateTime.now();
        }
      }
    });
  }

  String _getTimeSinceLastUpdate(Friend friend) {
    final now = DateTime.now();
    final diff = now.difference(friend.lastSeen);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${diff.inHours}h ago';
    }
  }

  Color _getConnectionQualityColor(Friend friend, ThemeData theme) {
    final timeSinceUpdate = DateTime.now()
        .difference(friend.lastSeen)
        .inSeconds;

    if (timeSinceUpdate < 30) {
      return Colors.green;
    } else if (timeSinceUpdate < 60) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<BluetoothProvider, LocationProvider>(
      builder: (context, bluetoothProvider, locationProvider, child) {
        final theme = Theme.of(context);
        final Friend? friend = bluetoothProvider.friends?.firstWhereOrNull(
          (friend) => friend.id == widget.friendId,
        );
        final isLocationEnabled = locationProvider.isLocationEnabled;
        final isConnected = bluetoothProvider.isConnected;

        if (!isLocationEnabled) {
          return _buildErrorState(
            icon: Icons.location_off,
            message: 'Please enable location services',
            theme: theme,
          );
        }

        if (!isConnected) {
          return _buildErrorState(
            icon: Icons.bluetooth_disabled,
            message: 'Please connect to your friend',
            theme: theme,
          );
        }

        if (friend == null) {
          return _buildErrorState(
            icon: Icons.person_search,
            message: 'Waiting for friend\'s location...',
            theme: theme,
          );
        }

        if (!_hasCompass) {
          return _buildErrorState(
            icon: Icons.compass_calibration,
            message: 'No compass available',
            theme: theme,
          );
        }

        return StreamBuilder<CompassEvent>(
          stream: FlutterCompass.events,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorState(
                icon: Icons.error_outline,
                message: 'Error getting compass heading',
                theme: theme,
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            _direction = snapshot.data!.heading ?? 0;

            final bearing = locationProvider.bearingToFriend(friend) ?? 0;
            final distance = locationProvider.getDistanceString(friend);
            final timeSinceUpdate = _getTimeSinceLastUpdate(friend);
            final connectionQuality = _getConnectionQualityColor(friend, theme);

            return Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: connectionQuality.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: connectionQuality.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: connectionQuality,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          timeSinceUpdate,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: connectionQuality,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        'Find ${friend.name}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Follow the arrow to meet up',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Compass Container
                      Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.05),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Compass ring
                            Container(
                              width: 240,
                              height: 240,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.1,
                                  ),
                                  width: 2,
                                ),
                              ),
                            ),
                            // Inner compass
                            Transform.rotate(
                              angle: ((_direction - bearing) * pi / 180) * -1,
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      theme.colorScheme.primary.withOpacity(
                                        0.15,
                                      ),
                                      theme.colorScheme.primary.withOpacity(
                                        0.05,
                                      ),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: CustomPaint(
                                  painter: ArrowPainter(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Distance Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.primary.withOpacity(0.1),
                              theme.colorScheme.primary.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.1,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.directions_walk_rounded,
                                color: theme.colorScheme.primary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Distance',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    distance,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildErrorState({
    required IconData icon,
    required String message,
    required ThemeData theme,
  }) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 64,
                  color: theme.colorScheme.primary.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                message,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArrowPainter extends CustomPainter {
  final Color color;

  ArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    path.moveTo(size.width * 0.5, size.height * 0.15); // Top point
    path.lineTo(size.width * 0.25, size.height * 0.65); // Bottom left
    path.lineTo(size.width * 0.5, size.height * 0.5); // Middle indent
    path.lineTo(size.width * 0.75, size.height * 0.65); // Bottom right
    path.close();

    // Draw filled arrow
    canvas.drawPath(path, paint);

    // Draw arrow outline for better definition
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
