import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:math';

class ProximityDetectionScreen extends StatefulWidget {
  final ScanResult targetDevice;

  const ProximityDetectionScreen({
    super.key,
    required this.targetDevice,
  });

  @override
  State<ProximityDetectionScreen> createState() =>
      _ProximityDetectionScreenState();
}

class _ProximityDetectionScreenState extends State<ProximityDetectionScreen> {
  // Current readings
  int _currentRssi = 0;
  double _estimatedDistance = 0.0;
  bool _isMonitoring = false;
  bool _isInProximity = false;

  // Proximity settings
  int _proximityThreshold = -60; // Default: close proximity
  bool _enableNotifications = true;
  bool _continuousMode = true;

  // History and monitoring
  final List<int> _rssiHistory = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  Timer? _alertCooldownTimer;
  bool _alertOnCooldown = false;

  // Alert tracking
  DateTime? _lastAlertTime;
  int _alertCount = 0;
  String _statusMessage = "Ready to start proximity detection";

  @override
  void initState() {
    super.initState();
    _currentRssi = widget.targetDevice.rssi;
    _calculateDistance();

    // Delay the proximity check until after the widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProximity();
    });
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
      return "Target Device";
    }
  }

  void _calculateDistance() {
    const double txPower = -59;
    const double pathLossExponent = 2.0;

    if (_currentRssi != 0) {
      double ratio = (txPower - _currentRssi) / (10.0 * pathLossExponent);
      _estimatedDistance = pow(10, ratio).toDouble();
    }
  }

  void _checkProximity() {
    if (!mounted) return;

    bool wasInProximity = _isInProximity;
    _isInProximity = _currentRssi >= _proximityThreshold;

    // Trigger alert if just entered proximity
    if (_isInProximity &&
        !wasInProximity &&
        _enableNotifications &&
        !_alertOnCooldown) {
      _showProximityAlert();
    }

    _updateStatusMessage();
  }

  void _showProximityAlert() {
    if (!mounted) return;

    _alertCount++;
    _lastAlertTime = DateTime.now();

    // Show overlay notification
    _showProximityOverlay();

    // Show snackbar as backup
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Close to ${_getDeviceName()} RSSI $_currentRssi',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Set cooldown to prevent spam
    _alertOnCooldown = true;
    _alertCooldownTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _alertOnCooldown = false;
      }
    });
  }

  void _showProximityOverlay() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.wifi_tethering, color: Colors.green, size: 28),
              const SizedBox(width: 12),
              const Text('Device Detected!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Close to ${_getDeviceName()}',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'RSSI: $_currentRssi dBm',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Distance: ~${_estimatedDistance.toStringAsFixed(1)}m',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Time: ${DateTime.now().toString().substring(11, 19)}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _enableNotifications = false;
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Stop Alerts'),
            ),
          ],
        );
      },
    );
  }

  void _updateStatusMessage() {
    if (!_isMonitoring) {
      _statusMessage = "Tap 'Start Detection' to begin proximity monitoring";
    } else if (_isInProximity) {
      _statusMessage = "🟢 IN PROXIMITY - Close to ${_getDeviceName()}!";
    } else {
      int distanceFromThreshold = (_proximityThreshold - _currentRssi).abs();
      _statusMessage =
          "🔵 Monitoring... Need $distanceFromThreshold dBm stronger signal";
    }
  }

  Future<void> _startMonitoring() async {
    if (_isMonitoring) return;

    setState(() {
      _isMonitoring = true;
      _alertCount = 0;
    });

    try {
      await FlutterBluePlus.startScan(
        timeout: _continuousMode ? null : const Duration(seconds: 60),
        androidUsesFineLocation: true,
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (!mounted) return;

        for (ScanResult result in results) {
          if (result.device.remoteId == widget.targetDevice.device.remoteId) {
            if (mounted) {
              setState(() {
                _currentRssi = result.rssi;
                _rssiHistory.add(_currentRssi);

                if (_rssiHistory.length > 50) {
                  _rssiHistory.removeAt(0);
                }

                _calculateDistance();
              });
              _checkProximity();
            }
            break;
          }
        }
      });
    } catch (e) {
      setState(() {
        _isMonitoring = false;
        _statusMessage = "❌ Error starting detection: $e";
      });
    }
  }

  Future<void> _stopMonitoring() async {
    if (!_isMonitoring) return;

    setState(() {
      _isMonitoring = false;
      _statusMessage = "Detection stopped";
    });

    try {
      await FlutterBluePlus.stopScan();
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      _alertCooldownTimer?.cancel();
      _alertCooldownTimer = null;
    } catch (e) {
      // Handle error silently
    }
  }

  Color _getProximityColor() {
    if (!_isMonitoring) return Colors.grey;
    return _isInProximity ? Colors.green : Colors.blue;
  }

  String _getProximityText() {
    if (!_isMonitoring) return "Not Monitoring";
    return _isInProximity ? "IN PROXIMITY" : "OUT OF RANGE";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proximity Detection'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phase 5: Proximity Detection',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Target Device Info
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.computer,
                        size: 32, color: Colors.green.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Target: ${_getDeviceName()}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'ID: ${widget.targetDevice.device.remoteId}',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Proximity Status
            Card(
              elevation: 4,
              color: _getProximityColor().withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isInProximity
                              ? Icons.wifi_tethering
                              : Icons.wifi_off,
                          size: 32,
                          color: _getProximityColor(),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _getProximityText(),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _getProximityColor(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Current readings
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              '$_currentRssi',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: _currentRssi >= _proximityThreshold
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            const Text('RSSI (dBm)'),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '${_estimatedDistance.toStringAsFixed(1)}m',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const Text('Distance'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Settings Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detection Settings',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text('Proximity Threshold: $_proximityThreshold dBm'),
                    Slider(
                      value: _proximityThreshold.toDouble(),
                      min: -90,
                      max: -40,
                      divisions: 50,
                      label: '$_proximityThreshold dBm',
                      onChanged: _isMonitoring
                          ? null
                          : (value) {
                              setState(() {
                                _proximityThreshold = value.round();
                              });
                            },
                    ),
                    SwitchListTile(
                      title: const Text('Enable Proximity Alerts'),
                      dense: true,
                      value: _enableNotifications,
                      onChanged: (value) {
                        setState(() {
                          _enableNotifications = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Continuous Monitoring'),
                      dense: true,
                      value: _continuousMode,
                      onChanged: _isMonitoring
                          ? null
                          : (value) {
                              setState(() {
                                _continuousMode = value;
                              });
                            },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Status Message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getProximityColor().withOpacity(0.1),
                border: Border.all(color: _getProximityColor()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _getProximityColor(),
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 16),

            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isMonitoring ? null : _startMonitoring,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      _isMonitoring ? 'Detecting...' : 'Start Detection',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isMonitoring ? _stopMonitoring : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Stop Detection',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Statistics
            if (_alertCount > 0)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '$_alertCount',
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const Text('Detections'),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '${_rssiHistory.length}',
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const Text('Readings'),
                        ],
                      ),
                      if (_lastAlertTime != null)
                        Column(
                          children: [
                            Text(
                              _lastAlertTime!.toString().substring(11, 19),
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const Text('Last Alert'),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Success Message
            if (_alertCount > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 32),
                    const SizedBox(height: 8),
                    const Text(
                      '🎉 Phase 5 Complete!',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your proximity detection is working! You\'ve received $_alertCount detection alerts.',
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
