import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../services/backend_service.dart';
import '../config/env.dart';

class SimplifiedProximityScreen extends StatefulWidget {
  const SimplifiedProximityScreen({super.key});

  @override
  State<SimplifiedProximityScreen> createState() => _SimplifiedProximityScreenState();
}

class _SimplifiedProximityScreenState extends State<SimplifiedProximityScreen> 
    with TickerProviderStateMixin {
  // Target device info
  static const String targetDeviceName = "Ray_Chen的筆記型電腦";
  static const String targetDeviceId = "428A26D3-FC17-А3С5-8B29-20F58A8ACC67";
  
  // Current state
  int _currentRssi = 0;
  bool _isDetecting = false;
  bool _deviceFound = false;
  String _statusMessage = "Starting Mac detection automatically...";
  String _proximityMessage = "";
  
  // Monitoring
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  Timer? _updateTimer;
  DateTime? _lastUpdate;
  bool _showGetClose = false;
  Timer? _getCloseTimer;
  late final BackendService _backend;
  
  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize backend service
    _backend = BackendService(baseUrl: kBackendBaseUrl);
    
    // Initialize animation
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)
    );
    
    // Automatically start detection when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDetection();
    });
  }

  @override
  void dispose() {
    _stopDetection();
    _getCloseTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startDetection() async {
    if (_isDetecting) return;

    setState(() {
      _isDetecting = true;
      _deviceFound = false;
      _statusMessage = "🔍 Searching for your Mac...";
      _proximityMessage = "";
    });

    // Start pulse animation
    _pulseController.repeat(reverse: true);

    try {
      // Start continuous BLE scanning with shorter timeout for frequent updates
      await FlutterBluePlus.startScan(
        timeout: const Duration(milliseconds: 500), // Short timeout for frequent scans
        androidUsesFineLocation: true,
      );

      // Listen for scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (!mounted) return;
        
        bool foundInThisScan = false;
        
        for (ScanResult result in results) {
          // Check if this is Ray's Mac by name or device ID
          bool isTargetDevice = false;
          
          // Check by device name
          String deviceName = "";
          if (result.device.platformName.isNotEmpty) {
            deviceName = result.device.platformName;
          } else if (result.advertisementData.advName.isNotEmpty) {
            deviceName = result.advertisementData.advName;
          }
          
          if (deviceName == targetDeviceName) {
            isTargetDevice = true;
          }
          
          // Check by device ID
          if (result.device.remoteId.toString().toUpperCase() == targetDeviceId.toUpperCase()) {
            isTargetDevice = true;
          }
          
          if (isTargetDevice) {
            foundInThisScan = true;
            _lastUpdate = DateTime.now();
            if (mounted) {
              setState(() {
                _deviceFound = true;
                _currentRssi = result.rssi;
                _updateStatusAndProximity();
              });
            }
            break;
          }
        }
        
        // If we didn't find the device in this scan cycle
        if (!foundInThisScan && mounted) {
          // Only update status if we haven't found it recently
          if (_lastUpdate == null || 
              DateTime.now().difference(_lastUpdate!).inSeconds > 3) {
            setState(() {
              _deviceFound = false;
              _statusMessage = "🔍 Searching for Ray_Chen的筆記型電腦...";
              _proximityMessage = "Mac not detected";
            });
          }
        }
      });

      // Set up a timer to restart scanning every second for consistent updates
      _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (!mounted || !_isDetecting) {
          timer.cancel();
          return;
        }
        
        try {
          // Stop current scan
          await FlutterBluePlus.stopScan();
          
          // Start a new scan
          await FlutterBluePlus.startScan(
            timeout: const Duration(milliseconds: 500),
            androidUsesFineLocation: true,
          );
        } catch (e) {
          // Handle scan restart errors silently
        }
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          _isDetecting = false;
          _statusMessage = "❌ Error starting detection: $e";
        });
      }
    }
  }

  Future<void> _stopDetection() async {
    if (!_isDetecting) return;

    setState(() {
      _isDetecting = false;
      _deviceFound = false;
      _statusMessage = "Detection stopped";
      _proximityMessage = "";
    });

    // Stop pulse animation
    _pulseController.stop();
    _pulseController.reset();

    try {
      // Cancel timer first
      _updateTimer?.cancel();
      _updateTimer = null;
      // Cancel get-close timer
      _getCloseTimer?.cancel();
      _getCloseTimer = null;
      
      // Stop scanning
      await FlutterBluePlus.stopScan();
      
      // Cancel subscription
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      
      // Reset last update
      _lastUpdate = null;
    } catch (e) {
      // Handle error silently
    }
  }

  void _updateStatusAndProximity() {
    if (!_deviceFound) return;
    String timeStr = DateTime.now().toString().substring(11, 19);
    _statusMessage = "✅ Mac found! RSSI: $_currentRssi dBm (Updated: $timeStr)";

    // Determine previous proximity before updating
    final String prevProximity = _proximityMessage;

    // Check proximity based on RSSI
    // RSSI closer to 0 = stronger signal = closer distance
    // RSSI more negative = weaker signal = farther distance
    if (_currentRssi > -50) {
      _proximityMessage = "close";  // Strong signal = close
    } else {
      _proximityMessage = "far";    // Weak signal = far
    }

    // As long as it's close, trigger the MRT function
    if (_proximityMessage == "close") {
      // Stop animation when we're close (detected)
      _pulseController.stop();
      _pulseController.reset();
      
      // Show transient "get close" message (only on transition)
      if (prevProximity == "far") {
        // cancel any existing timer
        _getCloseTimer?.cancel();
        _showGetClose = true;
        // clear after 2 seconds
        _getCloseTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _showGetClose = false;
            });
          }
        });
        // also show a quick snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('get close'), duration: Duration(seconds: 2)),
          );
        }
      }
      // Trigger MRT quick action every time we're close (every second)
      _handleQuickActionTap('00000000_iris_enter_mrt');
    } else {
      // Start animation when we're far (still detecting)
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  Color _getProximityColor() {
    if (!_deviceFound) return Colors.grey;
    if (_currentRssi > -50) return Colors.green; // close - green color  
    return Colors.red; // far - red color
  }

  Future<void> _handleQuickActionTap(String ref) async {
    // Lightweight modal progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final resp = await _backend.generateByRef(ref);
      final authUriStr = (resp['authUri'] ?? resp['auth_uri']) as String?;
      if (authUriStr == null || authUriStr.isEmpty) {
        _showSnack('未取得 authUri，請稍後重試');
        return;
      }

      final uri = Uri.parse(authUriStr);
      final can = await canLaunchUrl(uri);
      if (!can) {
        _showSnack('無法開啟連結');
        return;
      }

      final isHttp = uri.scheme == 'http' || uri.scheme == 'https';
      await launchUrl(
        uri,
        mode: isHttp
            ? LaunchMode.inAppBrowserView
            : LaunchMode.externalApplication,
      );
    } catch (e) {
      _showSnack('操作失敗：$e');
    } finally {
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Color _getBluetoothButtonColor() {
    if (!_isDetecting) return Colors.grey[400]!; // Not detecting
    if (!_deviceFound || _proximityMessage != "close") return Colors.blue; // Detecting (including when far)
    return Colors.green; // Detected (close)
  }

  String _getBluetoothStatusText() {
    if (!_isDetecting) return "Not Detecting";
    if (!_deviceFound || _proximityMessage != "close") return "Detecting...";
    return "Detected";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Bluetooth Button
              GestureDetector(
                onTap: _isDetecting ? _stopDetection : _startDetection,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    final bool shouldAnimate = _isDetecting && (_proximityMessage != "close" || !_deviceFound);
                    return Transform.scale(
                      scale: shouldAnimate ? _pulseAnimation.value : 1.0,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: _getBluetoothButtonColor(),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.bluetooth,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              
              // Status Text
              Text(
                _getBluetoothStatusText(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              
              const SizedBox(height: 80),
              
              // Leave Button
              GestureDetector(
                onTap: () {
                  _stopDetection();
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Center(
                    child: Text(
                      'Leave',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}