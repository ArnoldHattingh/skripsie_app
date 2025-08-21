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

  @override
  void initState() {
    super.initState();
    _checkCompass();
  }

  void _checkCompass() async {
    _hasCompass = FlutterCompass.events != null;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<BluetoothProvider, LocationProvider>(
      builder: (context, bluetoothProvider, locationProvider, child) {
        final theme = Theme.of(context);
        final Friend? friend = bluetoothProvider.friends?.firstWhereOrNull((friend) => friend.id == widget.friendId);
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

            final bearing =
                locationProvider.bearingToFriend(friend) ?? 0;
            final distance = locationProvider.getDistanceString(friend);

            // in your compass StreamBuilder:
            print("👤 User ID: ${bluetoothProvider.serviceUuid}");
            print("📍 Me: ${locationProvider.currentLocation?.name}");
            print("📍 Me: ${locationProvider.currentLocation?.latitude}");
            print("🤝 Friend: ${friend.name}");
            print("🤝 Friend: ${friend.latitude}");
            print("📐 Bearing: $bearing");

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
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        'Find Your Friend',
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
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Transform.rotate(
                          angle: ((_direction - bearing) * pi / 180) * -1,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  theme.colorScheme.primary.withOpacity(0.1),
                                  theme.colorScheme.primary.withOpacity(0.05),
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
                      ),
                      const Spacer(),
                      Card(
                        elevation: 0,
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.directions_walk_rounded,
                                color: theme.colorScheme.primary,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                distance,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
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
    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 80,
                color: theme.colorScheme.primary.withOpacity(0.5),
              ),
              const SizedBox(height: 24),
              Text(
                message,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.grey[700],
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

    final path = Path();
    path.moveTo(size.width * 0.5, size.height * 0.1); // Top point
    path.lineTo(size.width * 0.2, size.height * 0.7); // Bottom left
    path.lineTo(size.width * 0.5, size.height * 0.5); // Middle indent
    path.lineTo(size.width * 0.8, size.height * 0.7); // Bottom right
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
