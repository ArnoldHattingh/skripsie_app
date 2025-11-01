import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:skripsie/constants.dart';
import 'package:skripsie/providers/bluetooth_provider.dart';

class DetermineGroupInfoScreen extends StatefulWidget {
  const DetermineGroupInfoScreen({super.key});

  @override
  State<DetermineGroupInfoScreen> createState() =>
      _DetermineGroupInfoScreenState();
}

class _DetermineGroupInfoScreenState extends State<DetermineGroupInfoScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _waveAnimation;

  int _currentPhase = 0;
  String? _statusMessage;
  double? _currentFreqMhz;
  final Set<double> _triedFreqs = {};
  final List<_RssiAttemptResult> _attemptResults = [];

  final List<String> _phases = [
    'Determining group parameters...',
    'Scanning frequencies...',
    'Creating the group...',
  ];

  int? _selectedSpreadingFactor;
  bool _showSfDialog = true;
  bool _sfDialogShown = false;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );

    _waveAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(parent: _waveController, curve: Curves.linear));

    // Start animations
    _pulseController.repeat(reverse: true);
    _rotationController.repeat();
    _waveController.repeat();

    // Show SF selection dialog after the first frame, before running workflow
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showSfDialog && !_sfDialogShown) {
        _showSfDialog = false; // Only show once
        _sfDialogShown = true;
        _showSfPickerDialog(context);
      }
    });
  }

  Future<void> _showSfPickerDialog(BuildContext context) async {
    int tempSf = 8; // Default selection
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (sfContext) {
        return AlertDialog(
          title: const Text('Select Spreading Factor'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Please choose LoRa Spreading Factor (SF):',
                    style: TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  DropdownButton<int>(
                    value: tempSf,
                    items: List<DropdownMenuItem<int>>.generate(
                        6,
                        (idx) => DropdownMenuItem(
                              value: 7 + idx,
                              child: Text('SF${7 + idx}'),
                            )),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          tempSf = value;
                        });
                      }
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Optionally don't allow closing/cancelling
              },
              style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[400]
              ),
              child: const Text('Cancel', style: TextStyle(decoration: TextDecoration.lineThrough)),
            ),
            ElevatedButton(
              onPressed: () {
                _selectedSpreadingFactor = tempSf;
                Navigator.of(sfContext).pop();
                _runRssiWorkflow();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: PRIMARY_COLOR,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Frequencies in MHz, 125 kHz channels on 200 kHz raster (EU 863–870)
  static const List<double> _loraFreqsMhz = [
    863.1,
    863.3,
    863.5,
    863.7,
    863.9,
    864.1,
    864.3,
    864.5,
    864.7,
    864.9,
    865.1,
    865.3,
    865.5,
    865.7,
    865.9,
    866.1,
    866.3,
    866.5,
    866.7,
    866.9,
    867.1,
    867.3,
    867.5,
    867.7,
    867.9,
    868.1,
    868.3,
    868.5,
    868.7,
    868.9,
    869.1,
    869.3,
    869.5,
    869.7,
    869.9,
  ];

  // Dart implementation of getRandomLoRaFreq(), avoiding already tried freqs
  double _getRandomLoRaFreq({Set<double>? exclude}) {
    final excluded = exclude ?? {};
    final available = _loraFreqsMhz
        .where((f) => !excluded.contains(f))
        .toList();
    if (available.isEmpty) {
      // If somehow all excluded, reset
      available.addAll(_loraFreqsMhz);
    }
    final idx = math.Random().nextInt(available.length);
    final selectedFreq = available[idx];
    return selectedFreq;
  }

  Future<void> _runRssiWorkflow() async {
    // Do not start workflow until SF is selected
    if (_selectedSpreadingFactor == null) {
      if (!_sfDialogShown) {
        // Defensive: show the dialog if not shown yet
        _showSfPickerDialog(context);
      }
      return;
    }

    final provider = Provider.of<BluetoothProvider>(context, listen: false);

    // Try up to 3 unique frequencies
    for (int attempt = 0; attempt < 3; attempt++) {
      if (!mounted) {
        return;
      }

      final freqMhz = _getRandomLoRaFreq(exclude: _triedFreqs);
      _triedFreqs.add(freqMhz);
      _currentFreqMhz = freqMhz;

      setState(() {
        _currentPhase = 1;
        _statusMessage = 'Scanning ${freqMhz.toStringAsFixed(1)} MHz...';
      });

      // Build RSSI scan params for the device
      final scanParams = {
        'messageType': 'rssiBusy',
        'freq': freqMhz, // MHz as used elsewhere in app
        'bw_khz': 125.0,
        'ms': 4000,
        'sample_ms': 5,
        'settle_ms': 8,
        'debounce_samples': 2,
        'threshold_dbm': -95.0,
      };

      // Fire the request
      final started = await provider.startRssiScan(scanParams);

      if (!started) {
        // Treat as busy/no result if we cannot start
        _attemptResults.add(
          _RssiAttemptResult(
            frequencyMhz: freqMhz,
            busyScore: 1.0,
            isBusy: true,
            rawResults: const {},
          ),
        );
      } else {
        // Wait for results without timeout - let the bluetooth provider complete the scan
        final results = await _waitForRssiResults(expectedFreqMhz: freqMhz);

        final parsed = _parseRssiResults(results);

        _attemptResults.add(
          _RssiAttemptResult(
            frequencyMhz: freqMhz,
            busyScore: parsed.busyScore,
            isBusy: parsed.isBusy,
            rawResults: results ?? const {},
          ),
        );

        if (!parsed.isBusy) {
          // Good channel found
          if (!mounted) return;
          Navigator.of(context).pop({
            'centerFrequencyHz': (freqMhz * 1000000).round(),
            'bandwidthHz': 125000,
            'spreadingFactor': _selectedSpreadingFactor ?? 8,
          });
          return;
        }
      }

      // Busy path: inform user and retry with another frequency
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Network busy at ${freqMhz.toStringAsFixed(1)} MHz. Trying another frequency...',
          ),
          backgroundColor: Colors.orange[700],
        ),
      );
      setState(() {
        _currentPhase = 1;
        _statusMessage = 'Trying another frequency...';
      });
    }

    // All tried and busy: choose least busy
    if (_attemptResults.isNotEmpty) {
      _attemptResults.sort((a, b) => a.busyScore.compareTo(b.busyScore));
      final best = _attemptResults.first;
      if (!mounted) return;
      Navigator.of(context).pop({
        'centerFrequencyHz': (best.frequencyMhz * 1000000).round(),
        'bandwidthHz': 125000,
        'spreadingFactor': _selectedSpreadingFactor ?? 8,
      });
    } else {
      // Fallback: random freq
      final fallback = _getRandomLoRaFreq();
      if (!mounted) return;
      Navigator.of(context).pop({
        'centerFrequencyHz': (fallback * 1000000).round(),
        'bandwidthHz': 125000,
        'spreadingFactor': _selectedSpreadingFactor ?? 8,
      });
    }
  }

  Future<Map<String, dynamic>?> _waitForRssiResults({
    required double expectedFreqMhz,
  }) async {
    final provider = Provider.of<BluetoothProvider>(context, listen: false);

    Map<String, dynamic>? lastSeen;
    int checkCount = 0;

    // Wait indefinitely for results from the bluetooth provider
    while (true) {
      if (!mounted) {
        return lastSeen;
      }

      checkCount++;
      final res = provider.rssiScanResults;
      if (res != null) {
        lastSeen = Map<String, dynamic>.from(res);
        // Try to ensure this result is for the requested frequency if provided
        final resFreq =
            (res['freq'] ?? res['frequency'] ?? res['centerFrequencyMhz']);
        if (resFreq is num) {
          final diff = (resFreq.toDouble() - expectedFreqMhz).abs();
          if (diff < 0.05) {
            return lastSeen;
          }
        } else {
          // If no freq in result, assume it's for our request
          return lastSeen;
        }
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  _ParsedRssi _parseRssiResults(Map<String, dynamic>? results) {
    if (results == null) {
      return const _ParsedRssi(isBusy: true, busyScore: 1.0);
    }

    // Check for error first
    if (results['ok'] == false) {
      return const _ParsedRssi(isBusy: true, busyScore: 1.0);
    }

    // Parse new format: {"t":"rssi","ok":true,"busyPct":37.3,"samples":750,"min":-121.5,"max":-58.0,"avg":-102.7,"baseline":-105.3,"threshold":-99.3}
    if (results['t'] == 'rssi' && results['ok'] == true) {
      final busyPct = (results['busyPct'] as num?)?.toDouble() ?? 100.0;
      final busyScore = (busyPct / 100.0).clamp(0.0, 1.0);
      final isBusy = busyScore >= 0.5; // Consider busy if more than 50% busy
      return _ParsedRssi(isBusy: isBusy, busyScore: busyScore);
    }

    // Legacy format support
    final r = results['results'];
    // Heuristics: prefer explicit busy/busyScore; else derive from activity metrics
    if (results['busy'] is bool) {
      final busy = results['busy'] as bool;
      return _ParsedRssi(isBusy: busy, busyScore: busy ? 1.0 : 0.0);
    }
    if (results['busyScore'] is num) {
      final score = (results['busyScore'] as num).toDouble().clamp(0.0, 1.0);
      return _ParsedRssi(isBusy: score >= 0.5, busyScore: score);
    }
    if (results['busyPct'] is num) {
      final busyPct = (results['busyPct'] as num).toDouble();
      final score = (busyPct / 100.0).clamp(0.0, 1.0);
      return _ParsedRssi(isBusy: score >= 0.5, busyScore: score);
    }
    if (r is Map) {
      if (r['busy'] is bool) {
        final busy = r['busy'] as bool;
        return _ParsedRssi(isBusy: busy, busyScore: busy ? 1.0 : 0.0);
      }
      if (r['busyScore'] is num) {
        final score = (r['busyScore'] as num).toDouble().clamp(0.0, 1.0);
        return _ParsedRssi(isBusy: score >= 0.5, busyScore: score);
      }
      if (r['busyPct'] is num) {
        final busyPct = (r['busyPct'] as num).toDouble();
        final score = (busyPct / 100.0).clamp(0.0, 1.0);
        return _ParsedRssi(isBusy: score >= 0.5, busyScore: score);
      }
      if (r['activity'] is num) {
        final score = (r['activity'] as num).toDouble().clamp(0.0, 1.0);
        return _ParsedRssi(isBusy: score >= 0.5, busyScore: score);
      }
      if (r['duty'] is num) {
        final score = (r['duty'] as num).toDouble().clamp(0.0, 1.0);
        return _ParsedRssi(isBusy: score >= 0.5, busyScore: score);
      }
    }
    // Default conservative: consider busy
    return const _ParsedRssi(isBusy: true, busyScore: 1.0);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width / screenSize.height < 1.2;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              PRIMARY_COLOR.withOpacity(0.05),
              Colors.grey[50]!,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(isTablet ? 32.0 : 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: Colors.grey[600],
                        size: 28,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: PRIMARY_COLOR.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: PRIMARY_COLOR.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Scanning...',
                        style: TextStyle(
                          color: PRIMARY_COLOR,
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated loading visualization
                    SizedBox(
                      width: isTablet ? 300 : 250,
                      height: isTablet ? 300 : 250,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer rotating ring
                          AnimatedBuilder(
                            animation: _rotationAnimation,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _rotationAnimation.value,
                                child: Container(
                                  width: isTablet ? 280 : 230,
                                  height: isTablet ? 280 : 230,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: PRIMARY_COLOR.withOpacity(0.2),
                                      width: 2,
                                    ),
                                  ),
                                  child: Stack(
                                    children: List.generate(8, (index) {
                                      final angle = (index * math.pi * 2) / 8;
                                      return Positioned(
                                        left:
                                            (isTablet ? 140 : 115) +
                                            (isTablet ? 120 : 100) *
                                                math.cos(angle) -
                                            4,
                                        top:
                                            (isTablet ? 140 : 115) +
                                            (isTablet ? 120 : 100) *
                                                math.sin(angle) -
                                            4,
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: PRIMARY_COLOR.withOpacity(
                                              0.2 +
                                                  0.6 *
                                                      ((index +
                                                              _rotationAnimation
                                                                      .value *
                                                                  4) %
                                                          8) /
                                                      8,
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              );
                            },
                          ),

                          // Middle pulsing circle
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  width: isTablet ? 180 : 150,
                                  height: isTablet ? 180 : 150,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: PRIMARY_COLOR.withOpacity(0.05),
                                    border: Border.all(
                                      color: PRIMARY_COLOR.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          // Inner wave animation
                          AnimatedBuilder(
                            animation: _waveAnimation,
                            builder: (context, child) {
                              return CustomPaint(
                                size: Size(
                                  isTablet ? 120 : 100,
                                  isTablet ? 120 : 100,
                                ),
                                painter: WavePainter(
                                  animation: _waveAnimation.value,
                                  color: PRIMARY_COLOR,
                                ),
                              );
                            },
                          ),

                          // Center icon
                          Container(
                            width: isTablet ? 60 : 50,
                            height: isTablet ? 60 : 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: PRIMARY_COLOR,
                              boxShadow: [
                                BoxShadow(
                                  color: PRIMARY_COLOR.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.radio,
                              color: Colors.white,
                              size: isTablet ? 30 : 25,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isTablet ? 60 : 50),

                    // Phase text with animation
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: Column(
                        key: ValueKey(
                          _currentPhase.toString() + (_statusMessage ?? ''),
                        ),
                        children: [
                          Text(
                            _phases[_currentPhase],
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: isTablet ? 24 : 20,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_statusMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _statusMessage!,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: isTablet ? 16 : 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          if (_selectedSpreadingFactor == null) ...[
                            const SizedBox(height: 24),
                            Text(
                              "Awaiting SF selection...",
                              style: TextStyle(
                                color: PRIMARY_COLOR,
                                fontWeight: FontWeight.w700,
                                fontSize: isTablet ? 18 : 14,
                              ),
                            ),
                          ],
                          if (_selectedSpreadingFactor != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              "SF${_selectedSpreadingFactor}",
                              style: TextStyle(
                                color: PRIMARY_COLOR.withOpacity(0.86),
                                fontSize: isTablet ? 16 : 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    SizedBox(height: isTablet ? 40 : 32),

                    // Status indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) {
                        final isActive = index <= _currentPhase;
                        final isCompleted = index < _currentPhase;

                        return Container(
                          margin: EdgeInsets.symmetric(
                            horizontal: isTablet ? 12 : 8,
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: isTablet ? 16 : 12,
                                height: isTablet ? 16 : 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isCompleted
                                      ? PRIMARY_COLOR
                                      : isActive
                                      ? PRIMARY_COLOR.withOpacity(0.7)
                                      : Colors.grey[300],
                                  boxShadow: isActive
                                      ? [
                                          BoxShadow(
                                            color: PRIMARY_COLOR.withOpacity(
                                              0.3,
                                            ),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: isCompleted
                                    ? Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: isTablet ? 10 : 8,
                                      )
                                    : null,
                              ),
                              SizedBox(height: isTablet ? 8 : 6),
                              Text(
                                ['Params', 'Scan', 'Create'][index],
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.grey[800]
                                      : Colors.grey[500],
                                  fontSize: isTablet ? 12 : 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParsedRssi {
  final bool isBusy;
  final double busyScore;
  const _ParsedRssi({required this.isBusy, required this.busyScore});
}

class _RssiAttemptResult {
  final double frequencyMhz;
  final double busyScore;
  final bool isBusy;
  final Map<String, dynamic> rawResults;

  _RssiAttemptResult({
    required this.frequencyMhz,
    required this.busyScore,
    required this.isBusy,
    required this.rawResults,
  });
}

class WavePainter extends CustomPainter {
  final double animation;
  final Color color;

  WavePainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final waveRadius =
          radius *
          (0.3 + 0.3 * i) *
          (1 + 0.3 * math.sin(animation + i * math.pi / 3));
      canvas.drawCircle(center, waveRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
