import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'ble_scanning_screen.dart';

class BleProximityScreen extends StatefulWidget {
  const BleProximityScreen({super.key});

  @override
  State<BleProximityScreen> createState() => _BleProximityScreenState();
}

class _BleProximityScreenState extends State<BleProximityScreen> {
  bool _bluetoothPermissionGranted = false;
  bool _locationPermissionGranted = false;
  String _statusMessage = "Checking permissions...";

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      // Check Bluetooth permissions
      PermissionStatus bluetoothStatus;
      PermissionStatus locationStatus;

      if (Platform.isIOS) {
        bluetoothStatus = await Permission.bluetooth.status;
        locationStatus = await Permission.locationWhenInUse.status;
        
        // On iOS, sometimes we need to check if we can actually use Bluetooth
        // even if permission shows as granted
        print("iOS Bluetooth status: $bluetoothStatus");
        print("iOS Location status: $locationStatus");
      } else {
        bluetoothStatus = await Permission.bluetoothScan.status;
        locationStatus = await Permission.location.status;
      }

      setState(() {
        _bluetoothPermissionGranted = bluetoothStatus.isGranted;
        _locationPermissionGranted = locationStatus.isGranted;
        _updateStatusMessage();
      });
    } catch (e) {
      setState(() {
        _statusMessage = "❌ Error checking permissions: $e";
      });
    }
  }

  Future<void> _requestPermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses;
      
      if (Platform.isIOS) {
        // For iOS, request permissions individually with better handling
        final bluetoothStatus = await Permission.bluetooth.request();
        final locationStatus = await Permission.locationWhenInUse.request();
        
        statuses = {
          Permission.bluetooth: bluetoothStatus,
          Permission.locationWhenInUse: locationStatus,
        };
        
        // Show alert if permissions are permanently denied
        if (bluetoothStatus.isPermanentlyDenied || locationStatus.isPermanentlyDenied) {
          _showPermissionDeniedDialog();
        }
      } else {
        statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();
      }

      setState(() {
        if (Platform.isIOS) {
          _bluetoothPermissionGranted = statuses[Permission.bluetooth]?.isGranted ?? false;
          _locationPermissionGranted = statuses[Permission.locationWhenInUse]?.isGranted ?? false;
        } else {
          _bluetoothPermissionGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
          _locationPermissionGranted = statuses[Permission.location]?.isGranted ?? false;
        }
        _updateStatusMessage();
      });
    } catch (e) {
      setState(() {
        _statusMessage = "❌ Error requesting permissions: $e";
      });
    }
  }

  void _showPermissionDeniedDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permissions Required'),
          content: const Text(
            'This app needs Bluetooth and Location permissions to work. '
            'Please go to Settings > Privacy & Security > Bluetooth/Location '
            'and enable permissions for this app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void _updateStatusMessage() {
    if (Platform.isIOS) {
      // On iOS, we primarily need Bluetooth permission
      if (_bluetoothPermissionGranted) {
        _statusMessage = "✅ Bluetooth permission granted! Ready for BLE scanning.";
      } else {
        _statusMessage = "❌ Missing Bluetooth permission";
      }
    } else {
      // Android requires both
      if (_bluetoothPermissionGranted && _locationPermissionGranted) {
        _statusMessage = "✅ All permissions granted! Ready for BLE scanning.";
      } else {
        List<String> missing = [];
        if (!_bluetoothPermissionGranted) missing.add("Bluetooth");
        if (!_locationPermissionGranted) missing.add("Location");
        _statusMessage = "❌ Missing permissions: ${missing.join(', ')}";
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Proximity Detection'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phase 1: Permissions Setup',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Permission Status Cards
            _buildPermissionCard(
              'Bluetooth Permission',
              _bluetoothPermissionGranted,
              Platform.isIOS ? 'Required for BLE scanning' : 'Required for BLE scanning and connecting',
            ),
            
            const SizedBox(height: 12),
            
            _buildPermissionCard(
              'Location Permission', 
              _locationPermissionGranted,
              'Required for BLE device discovery (Android requirement)',
            ),
            
            const SizedBox(height: 20),
            
            // Status Message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _bluetoothPermissionGranted && _locationPermissionGranted 
                    ? Colors.green.shade50 
                    : Colors.orange.shade50,
                border: Border.all(
                  color: _bluetoothPermissionGranted && _locationPermissionGranted 
                      ? Colors.green 
                      : Colors.orange,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 16,
                  color: _bluetoothPermissionGranted && _locationPermissionGranted 
                      ? Colors.green.shade800 
                      : Colors.orange.shade800,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            if (!((Platform.isIOS && _bluetoothPermissionGranted) || 
                  (!Platform.isIOS && _bluetoothPermissionGranted && _locationPermissionGranted)))
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _requestPermissions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Request Permissions', style: TextStyle(fontSize: 16)),
                ),
              ),
            
            if ((Platform.isIOS && _bluetoothPermissionGranted) || 
                (!Platform.isIOS && _bluetoothPermissionGranted && _locationPermissionGranted))
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const BleScanningScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Continue to Phase 2', style: TextStyle(fontSize: 16)),
                ),
              ),
            
            const SizedBox(height: 20),
            
            // Refresh Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _checkPermissions,
                child: const Text('Refresh Permission Status'),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // iOS Bypass for testing
            if (Platform.isIOS)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const BleScanningScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                  ),
                  child: const Text('Skip to Phase 2 (iOS Test Mode)'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard(String title, bool granted, String description) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              granted ? Icons.check_circle : Icons.cancel,
              color: granted ? Colors.green : Colors.red,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Text(
              granted ? 'Granted' : 'Denied',
              style: TextStyle(
                color: granted ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}