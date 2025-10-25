import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'rssi_monitoring_screen.dart';
import 'proximity_detection_screen.dart';

class DeviceFilteringScreen extends StatefulWidget {
  const DeviceFilteringScreen({super.key});

  @override
  State<DeviceFilteringScreen> createState() => _DeviceFilteringScreenState();
}

class _DeviceFilteringScreenState extends State<DeviceFilteringScreen> {
  List<ScanResult> _allDevices = [];
  List<ScanResult> _filteredDevices = [];
  bool _isScanning = false;
  String _statusMessage = "Ready to scan for devices";
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  
  // Filter settings
  String _nameFilter = "";
  int _rssiThreshold = -80;
  bool _hideUnknownDevices = false;
  bool _macDevicesOnly = false;
  
  // Predefined Mac device patterns
  final List<String> _macDevicePatterns = [
    'mac',
    'macbook',
    'imac',
    'apple',
    'AirPods',
    'iPhone',
    'iPad',
    'Apple',
    'Magic',
    'Beats',
  ];

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
      BluetoothAdapterState adapterState = await FlutterBluePlus.adapterState.first;
      
      if (adapterState == BluetoothAdapterState.on) {
        setState(() {
          _statusMessage = "✅ Bluetooth ready. Configure filters and start scanning.";
        });
      } else {
        setState(() {
          _statusMessage = "❌ Bluetooth is not enabled.";
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
        _allDevices.clear();
        _filteredDevices.clear();
        _statusMessage = "🔍 Scanning for devices with filters...";
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          _allDevices = results;
          _applyFilters();
        });
      });

      Timer(const Duration(seconds: 15), () {
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
        _statusMessage = _filteredDevices.isEmpty 
            ? "Scan completed. No devices match your filters." 
            : "Scan completed. Found ${_filteredDevices.length} matching device(s).";
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _statusMessage = "❌ Error stopping scan: $e";
      });
    }
  }

  void _applyFilters() {
    _filteredDevices = _allDevices.where((result) {
      // RSSI filter
      if (result.rssi < _rssiThreshold) return false;
      
      // Get device name
      String deviceName = _getDeviceName(result).toLowerCase();
      
      // Hide unknown devices filter
      if (_hideUnknownDevices && deviceName == "unknown device") return false;
      
      // Name filter
      if (_nameFilter.isNotEmpty && 
          !deviceName.contains(_nameFilter.toLowerCase())) {
        return false;
      }
      
      // Mac devices only filter
      if (_macDevicesOnly) {
        bool isMacDevice = _macDevicePatterns.any((pattern) => 
            deviceName.contains(pattern.toLowerCase()));
        if (!isMacDevice) return false;
      }
      
      return true;
    }).toList();
    
    // Sort by RSSI (strongest first)
    _filteredDevices.sort((a, b) => b.rssi.compareTo(a.rssi));
    
    _statusMessage = _isScanning 
        ? "Scanning... Found ${_filteredDevices.length} matching devices"
        : "Found ${_filteredDevices.length} matching device(s) out of ${_allDevices.length} total";
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

  bool _isPotentialMac(ScanResult result) {
    String deviceName = _getDeviceName(result).toLowerCase();
    return _macDevicePatterns.any((pattern) => 
        deviceName.contains(pattern.toLowerCase()));
  }

  void _setTargetDevice(ScanResult device) {
    // Show options to go to RSSI monitoring or directly to proximity detection
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Monitor ${_getDeviceName(device)}'),
          content: const Text('How would like to monitor this device?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => RssiMonitoringScreen(targetDevice: device),
                  ),
                );
              },
              child: const Text('RSSI Monitoring'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => ProximityDetectionScreen(targetDevice: device),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Proximity Detection'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Device Filtering'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phase 4: Device Filtering',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Filter Controls
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filter Settings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    // Name Filter
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Device Name Filter',
                        hintText: 'Enter device name (e.g., "Mac", "iPhone")',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _nameFilter = value;
                          _applyFilters();
                        });
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // RSSI Threshold
                    Text('Minimum Signal Strength: $_rssiThreshold dBm'),
                    Slider(
                      value: _rssiThreshold.toDouble(),
                      min: -100,
                      max: -30,
                      divisions: 70,
                      label: '$_rssiThreshold dBm',
                      onChanged: (value) {
                        setState(() {
                          _rssiThreshold = value.round();
                          _applyFilters();
                        });
                      },
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Filter Checkboxes
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            title: const Text('Hide Unknown'),
                            dense: true,
                            value: _hideUnknownDevices,
                            onChanged: (value) {
                              setState(() {
                                _hideUnknownDevices = value ?? false;
                                _applyFilters();
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: CheckboxListTile(
                            title: const Text('Mac/Apple Only'),
                            dense: true,
                            value: _macDevicesOnly,
                            onChanged: (value) {
                              setState(() {
                                _macDevicesOnly = value ?? false;
                                _applyFilters();
                              });
                            },
                          ),
                        ),
                      ],
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
                color: _isScanning 
                    ? Colors.blue.shade50 
                    : _filteredDevices.isNotEmpty 
                        ? Colors.green.shade50 
                        : Colors.grey.shade50,
                border: Border.all(
                  color: _isScanning 
                      ? Colors.blue 
                      : _filteredDevices.isNotEmpty 
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
                      _filteredDevices.isNotEmpty ? Icons.filter_alt : Icons.filter_alt_off,
                      color: _filteredDevices.isNotEmpty ? Colors.green : Colors.grey,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_statusMessage, style: const TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
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
                    child: Text(_isScanning ? 'Scanning...' : 'Start Filtered Scan'),
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
            
            const SizedBox(height: 20),
            
            // Results Header
            Text(
              'Filtered Devices (${_filteredDevices.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            // Device List
            SizedBox(
              height: 300, // Fixed height to prevent overflow
              child: _filteredDevices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.filter_alt_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No devices match your filters.\nTry adjusting the filter settings above.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredDevices.length,
                      itemBuilder: (context, index) {
                        final result = _filteredDevices[index];
                        final deviceName = _getDeviceName(result);
                        final deviceId = result.device.remoteId.toString();
                        final isPotentialMac = _isPotentialMac(result);
                        
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            onTap: () => _setTargetDevice(result),
                            leading: Stack(
                              children: [
                                Icon(
                                  isPotentialMac ? Icons.computer : Icons.bluetooth,
                                  color: isPotentialMac ? Colors.green : Colors.blue,
                                  size: 28,
                                ),
                                if (isPotentialMac)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(
                                        color: Colors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.star,
                                        size: 8,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              deviceName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isPotentialMac ? Colors.green.shade700 : Colors.black,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ID: ${deviceId.substring(0, 17)}...'),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      'RSSI: ${result.rssi} dBm',
                                      style: TextStyle(
                                        color: result.rssi > -60 
                                            ? Colors.green 
                                            : result.rssi > -80 
                                                ? Colors.orange 
                                                : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (isPotentialMac) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          'Mac Device',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.green.shade800,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Tap to set as target device →',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}