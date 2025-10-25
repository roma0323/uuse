import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:math';
import 'proximity_detection_screen.dart';

class RssiMonitoringScreen extends StatefulWidget {
  final ScanResult targetDevice;

  const RssiMonitoringScreen({
    super.key,
    required this.targetDevice,
  });

  @override
  State<RssiMonitoringScreen> createState() => _RssiMonitoringScreenState();
}

class _RssiMonitoringScreenState extends State<RssiMonitoringScreen> {
  final List<int> _rssiHistory = [];
  int _currentRssi = 0;
  double _estimatedDistance = 0.0;
  bool _isMonitoring = false;
  String _proximityStatus = "Unknown";
  Timer? _monitoringTimer;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  // RSSI thresholds for proximity detection
  static const int _veryCloseThreshold = -40;
  static const int _closeThreshold = -60;
  static const int _mediumThreshold = -80;

  @override
  void initState() {
    super.initState();
    _currentRssi = widget.targetDevice.rssi;
    _rssiHistory.add(_currentRssi);
    _updateProximityStatus();
    _calculateDistance();
  }

  @override
  void dispose() {
    _stopMonitoring();
    super.dispose();
  }

  String _getDeviceName() {
    if (widget.targetDevice.device.platformName.isNotEmpty) {
      return widget.targetDevice.device.platformName;
    } else if (widget.targetDevice.advertisementData.advName.isNotEmpty) {
      return widget.targetDevice.advertisementData.advName;
    } else {
      return "Unknown Device";
    }
  }

  void _updateProximityStatus() {
    if (_currentRssi >= _veryCloseThreshold) {
      _proximityStatus = "Very Close";
    } else if (_currentRssi >= _closeThreshold) {
      _proximityStatus = "Close";
    } else if (_currentRssi >= _mediumThreshold) {
      _proximityStatus = "Medium";
    } else {
      _proximityStatus = "Far";
    }
  }

  void _calculateDistance() {
    // Simplified RSSI to distance calculation
    // Distance = 10^((Tx Power - RSSI) / (10 * n))
    // Assuming Tx Power = -59 dBm and path loss exponent n = 2
    const double txPower = -59;
    const double pathLossExponent = 2.0;

    if (_currentRssi != 0) {
      double ratio = (txPower - _currentRssi) / (10.0 * pathLossExponent);
      _estimatedDistance = pow(10, ratio).toDouble();
    }
  }

  Future<void> _startMonitoring() async {
    if (_isMonitoring) return;

    setState(() {
      _isMonitoring = true;
    });

    try {
      // Start scanning to get continuous RSSI updates
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 60),
        androidUsesFineLocation: true,
      );

      // Listen for scan results and filter for our target device
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          if (result.device.remoteId == widget.targetDevice.device.remoteId) {
            setState(() {
              _currentRssi = result.rssi;
              _rssiHistory.add(_currentRssi);

              // Keep only last 20 readings for history
              if (_rssiHistory.length > 20) {
                _rssiHistory.removeAt(0);
              }

              _updateProximityStatus();
              _calculateDistance();
            });
            break;
          }
        }
      });
    } catch (e) {
      setState(() {
        _isMonitoring = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting monitoring: $e')),
        );
      }
    }
  }

  Future<void> _stopMonitoring() async {
    if (!_isMonitoring) return;

    setState(() {
      _isMonitoring = false;
    });

    try {
      await FlutterBluePlus.stopScan();
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      _monitoringTimer?.cancel();
      _monitoringTimer = null;
    } catch (e) {
      // Handle error silently
    }
  }

  Color _getRssiColor(int rssi) {
    if (rssi >= _veryCloseThreshold) return Colors.green;
    if (rssi >= _closeThreshold) return Colors.lightGreen;
    if (rssi >= _mediumThreshold) return Colors.orange;
    return Colors.red;
  }

  Color _getProximityColor() {
    switch (_proximityStatus) {
      case "Very Close":
        return Colors.green;
      case "Close":
        return Colors.lightGreen;
      case "Medium":
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  double _getAverageRssi() {
    if (_rssiHistory.isEmpty) return 0;
    return _rssiHistory.reduce((a, b) => a + b) / _rssiHistory.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RSSI Monitoring'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phase 3: RSSI Monitoring & Distance',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Device Info Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bluetooth,
                            size: 24, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getDeviceName(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Device ID: ${widget.targetDevice.device.remoteId}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // RSSI Display
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              '$_currentRssi',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: _getRssiColor(_currentRssi),
                              ),
                            ),
                            const Text('Current RSSI (dBm)'),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '${_getAverageRssi().toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const Text('Average RSSI'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Distance & Proximity
            Row(
              children: [
                Expanded(
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            '${_estimatedDistance.toStringAsFixed(1)}m',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const Text('Estimated Distance'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            _proximityStatus,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _getProximityColor(),
                            ),
                          ),
                          const Text('Proximity'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isMonitoring ? null : _startMonitoring,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                        _isMonitoring ? 'Monitoring...' : 'Start Monitoring'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isMonitoring ? _stopMonitoring : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Stop Monitoring'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // RSSI History Chart
            const Text(
              'RSSI History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _rssiHistory.length < 2
                      ? const Center(
                          child: Text(
                            'Start monitoring to see RSSI history chart',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : CustomPaint(
                          size: Size.infinite,
                          painter: RssiChartPainter(_rssiHistory),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Next Phase Button
            if (_rssiHistory.length > 5)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => ProximityDetectionScreen(
                            targetDevice: widget.targetDevice),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Continue to Phase 5: Proximity Detection!',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class RssiChartPainter extends CustomPainter {
  final List<int> rssiValues;

  RssiChartPainter(this.rssiValues);

  @override
  void paint(Canvas canvas, Size size) {
    if (rssiValues.length < 2) return;

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();

    // Find min and max for scaling
    final minRssi = rssiValues.reduce((a, b) => a < b ? a : b).toDouble();
    final maxRssi = rssiValues.reduce((a, b) => a > b ? a : b).toDouble();
    final range = maxRssi - minRssi;

    if (range == 0) return;

    // Draw the line chart
    for (int i = 0; i < rssiValues.length; i++) {
      final x = (i / (rssiValues.length - 1)) * size.width;
      final y = size.height - ((rssiValues[i] - minRssi) / range) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Draw grid lines and labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Y-axis labels (RSSI values)
    for (int i = 0; i <= 4; i++) {
      final value = minRssi + (range * i / 4);
      final y = size.height - (i / 4) * size.height;

      textPainter.text = TextSpan(
        text: value.toStringAsFixed(0),
        style: const TextStyle(color: Colors.grey, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(-30, y - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
