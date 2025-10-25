import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'rssi_monitoring_screen.dart';
import 'device_filtering_screen.dart';

class BleScanningScreen extends StatefulWidget {
  const BleScanningScreen({super.key});

  @override
  State<BleScanningScreen> createState() => _BleScanningScreenState();
}

class _BleScanningScreenState extends State<BleScanningScreen> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  String _statusMessage = "Ready to scan for BLE devices";
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _checkBluetoothState();
  }

  @override
  void dispose() {
    _stopScanning();
    super.dispose();
  }

  Future<void> _checkBluetoothState() async {
    try {
      // Check if Bluetooth is available and enabled
      BluetoothAdapterState adapterState =
          await FlutterBluePlus.adapterState.first;

      if (adapterState == BluetoothAdapterState.on) {
        setState(() {
          _statusMessage =
              "✅ Bluetooth is ready. Tap 'Start Scanning' to begin.";
        });
      } else {
        setState(() {
          _statusMessage =
              "❌ Bluetooth is not enabled. Please enable Bluetooth.";
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "❌ Error checking Bluetooth: $e";
      });
    }
  }

  Future<void> _startScanning() async {
    if (_isScanning) return;

    try {
      setState(() {
        _isScanning = true;
        _scanResults.clear();
        _statusMessage = "🔍 Scanning for BLE devices...";
      });

      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: true,
      );

      // Listen to scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          _scanResults = results;
          _statusMessage = "Found ${results.length} device(s)";
        });
      });

      // Auto-stop after timeout
      Timer(const Duration(seconds: 10), () {
        if (_isScanning) {
          _stopScanning();
        }
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _statusMessage = "❌ Error starting scan: $e";
      });
    }
  }

  Future<void> _stopScanning() async {
    if (!_isScanning) return;

    try {
      await FlutterBluePlus.stopScan();
      await _scanSubscription?.cancel();
      _scanSubscription = null;

      setState(() {
        _isScanning = false;
        _statusMessage = _scanResults.isEmpty
            ? "Scan completed. No devices found."
            : "Scan completed. Found ${_scanResults.length} device(s).";
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _statusMessage = "❌ Error stopping scan: $e";
      });
    }
  }

  String _getDeviceName(ScanResult result) {
    if (result.device.platformName.isNotEmpty) {
      return result.device.platformName;
    } else if (result.advertisementData.advName.isNotEmpty) {
      return result.advertisementData.advName;
    } else {
      return "Unknown Device";
    }
  }

  String _getDeviceId(ScanResult result) {
    return result.device.remoteId.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Device Scanner'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phase 2: BLE Device Discovery',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Status Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isScanning
                    ? Colors.blue.shade50
                    : _scanResults.isNotEmpty
                        ? Colors.green.shade50
                        : Colors.grey.shade50,
                border: Border.all(
                  color: _isScanning
                      ? Colors.blue
                      : _scanResults.isNotEmpty
                          ? Colors.green
                          : Colors.grey,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  if (_isScanning)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      _scanResults.isNotEmpty
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth,
                      color:
                          _scanResults.isNotEmpty ? Colors.green : Colors.grey,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isScanning ? null : _startScanning,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(_isScanning ? 'Scanning...' : 'Start Scanning'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isScanning ? _stopScanning : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Stop Scanning'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Results Header
            Text(
              'Discovered Devices (${_scanResults.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Device List
            Expanded(
              child: _scanResults.isEmpty
                  ? const Center(
                      child: Text(
                        'No devices found.\nStart scanning to discover BLE devices.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _scanResults.length,
                      itemBuilder: (context, index) {
                        final result = _scanResults[index];
                        final deviceName = _getDeviceName(result);
                        final deviceId = _getDeviceId(result);

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => RssiMonitoringScreen(
                                    targetDevice: result,
                                  ),
                                ),
                              );
                            },
                            leading: const Icon(
                              Icons.bluetooth,
                              color: Colors.blue,
                              size: 28,
                            ),
                            title: Text(
                              deviceName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ID: ${deviceId.substring(0, 17)}...'),
                                const SizedBox(height: 4),
                                Text(
                                  'Signal Strength: ${result.rssi} dBm',
                                  style: TextStyle(
                                    color: result.rssi > -60
                                        ? Colors.green
                                        : result.rssi > -80
                                            ? Colors.orange
                                            : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Tap to monitor RSSI →',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: result.rssi > -60
                                    ? Colors.green.shade100
                                    : result.rssi > -80
                                        ? Colors.orange.shade100
                                        : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                result.rssi > -60
                                    ? 'Close'
                                    : result.rssi > -80
                                        ? 'Medium'
                                        : 'Far',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: result.rssi > -60
                                      ? Colors.green.shade800
                                      : result.rssi > -80
                                          ? Colors.orange.shade800
                                          : Colors.red.shade800,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 16),

            // Next Phase Button
            if (_scanResults.isNotEmpty && !_isScanning)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const DeviceFilteringScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Continue to Phase 4: Smart Filtering',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Phase 2 Complete! You can tap any device above to monitor it directly.'),
                            backgroundColor: Colors.blue,
                          ),
                        );
                      },
                      child: const Text(
                          'Or tap any device above for direct monitoring'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
