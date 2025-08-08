import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

void main() {
  // Force landscape orientation for better control
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const MecanumCarApp());
}

class MecanumCarApp extends StatelessWidget {
  const MecanumCarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Control',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const ControlPage(),
      debugShowCheckedModeBanner: false, // Remove debug banner
    );
  }
}

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  // Connection variables
  IOWebSocketChannel? wifiChannel;
  BluetoothDevice? bluetoothDevice;
  BluetoothCharacteristic? txCharacteristic;

  bool isWifiConnected = false;
  bool isBluetoothConnected = false;

  String wifiStatus = 'Disconnected';
  String bluetoothStatus = 'Disconnected';

  // Bluetooth scanning
  bool isScanning = false;
  List<ScanResult> scanResults = [];
  StreamSubscription? scanSubscription;

  // Control variables
  String _lastCommand = 'STOP';
  int _currentSpeed = 130; // Default speed for main directions
  final int _rotationSpeed = 120; // Fixed speed for rotation
  bool _isButtonPressed = false;

  // Command debouncing - optimized intervals
  String _lastSentCommand = '';
  int _lastCommandTime = 0;
  final int _minCommandInterval = 5; // OPTIMIZED: Reduced from 10ms to 5ms for faster response
  final int _rotationCommandInterval = 0; // No throttling for rotation commands

  // ESP32 Bluetooth service and characteristic UUIDs
  final String ESP32_SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  final String ESP32_CHARACTERISTIC_UUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";

  // Command buffer for speed optimization
  final Map<String, List<int>> _commandCache = {};

  // Command queue for high-priority commands
  final List<String> _priorityCommands = [];
  Timer? _priorityCommandTimer;

  @override
  void initState() {
    super.initState();
    // Initialize connections
    connectWiFi();
    initBluetooth();

    // Pre-encode common commands for speed
    _initCommandCache();

    // Start priority command processor
    _startPriorityCommandProcessor();
  }

  // OPTIMIZATION: Process high-priority commands at fixed intervals
  void _startPriorityCommandProcessor() {
    _priorityCommandTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (_priorityCommands.isNotEmpty) {
        final cmd = _priorityCommands.removeAt(0);
        _sendDirectCommand(cmd);
      }
    });
  }

  // Pre-encode commands to UTF8 to avoid doing this repeatedly
  void _initCommandCache() {
    // Prepare common commands with different speeds
    List<String> commands = [
      'FORWARD', 'BACKWARD', 'SIDEWAYS_LEFT', 'SIDEWAYS_RIGHT',
      'DIAGONAL_LEFT', 'DIAGONAL_RIGHT', 'DIAGONAL_BACK_LEFT', 'DIAGONAL_BACK_RIGHT',
      'ROTATE_LEFT_CORNER', 'ROTATE_RIGHT_CORNER', 'ROTATE_CENTER_CCW', 'ROTATE_CENTER_CW',
      'STOP'
    ];

    List<int> speeds = [0, 50, 75, 100, 125, 150, 175, 200, 225, 255];

    for (var cmd in commands) {
      for (var speed in speeds) {
        String fullCommand = '$cmd:$speed';
        _commandCache[fullCommand] = utf8.encode(fullCommand);
      }
    }

    print('Command cache initialized with ${_commandCache.length} entries');
  }

  // Initialize Bluetooth with optimized settings
  void initBluetooth() async {
    FlutterBluePlus.setLogLevel(LogLevel.error); // Reduce logging overhead

    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        setState(() {
          bluetoothStatus = 'Ready';
        });
      } else {
        setState(() {
          bluetoothStatus = 'Off';
          isBluetoothConnected = false;
        });
      }
    });
  }

  // OPTIMIZED: WiFi connection with fast ping interval
  void connectWiFi() {
    try {
      setState(() {
        wifiStatus = 'Connecting...';
      });

      // Use standard WebSocket with ping interval
      wifiChannel = IOWebSocketChannel.connect(
        'ws://192.168.4.1:81',
        pingInterval: const Duration(seconds: 1), // Keep connection alive
      );

      wifiChannel!.stream.listen(
            (message) {
          // Successfully received message
          print('Received from ESP32: $message');
        },
        onError: (error) {
          setState(() {
            wifiStatus = 'Error';
            isWifiConnected = false;
          });

          // Try to reconnect immediately on error
          Future.delayed(const Duration(seconds: 2), () {
            if (!isWifiConnected) {
              connectWiFi();
            }
          });
        },
        onDone: () {
          setState(() {
            wifiStatus = 'Disconnected';
            isWifiConnected = false;
          });

          // Try to reconnect after delay
          Future.delayed(const Duration(seconds: 3), () {
            if (!isWifiConnected) {
              connectWiFi();
            }
          });
        },
      );

      setState(() {
        wifiStatus = 'Connected';
        isWifiConnected = true;
      });

      // Test connection with a ping
      wifiChannel!.sink.add('PING');
    } catch (e) {
      setState(() {
        wifiStatus = 'Failed';
        isWifiConnected = false;
      });

      // Try again shortly
      Future.delayed(const Duration(seconds: 2), connectWiFi);
    }
  }

  // OPTIMIZED: Bluetooth scanning with low latency mode
  void startBluetoothScan() async {
    if (isScanning) return;

    if (await FlutterBluePlus.isAvailable == false) {
      setState(() {
        bluetoothStatus = 'Not available';
      });
      return;
    }

    scanSubscription?.cancel();
    scanSubscription = null;

    setState(() {
      isScanning = true;
      bluetoothStatus = 'Scanning...';
      scanResults = [];
    });

    try {
      try {
        await FlutterBluePlus.stopScan();
      } catch (e) {
        // Continue anyway
      }

      // Short delay to ensure BLE stack is reset
      await Future.delayed(const Duration(milliseconds: 50));

      scanSubscription = FlutterBluePlus.scanResults.listen(
            (results) {
          setState(() {
            scanResults = results;
          });
        },
        onDone: () {
          setState(() {
            isScanning = false;
          });
        },
        onError: (error) {
          setState(() {
            isScanning = false;
            bluetoothStatus = 'Scan error';
          });
        },
      );

      // OPTIMIZATION: Use low latency scan mode & shorter timeout
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 3),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      setState(() {
        isScanning = false;
        if (scanResults.isEmpty) {
          bluetoothStatus = 'No devices';
        } else {
          bluetoothStatus = 'Found ${scanResults.length}';
        }
      });
    } catch (e) {
      setState(() {
        isScanning = false;
        bluetoothStatus = 'Scan error';
      });
    }
  }

  // OPTIMIZED: Bluetooth connection
  void connectToBluetoothDevice(BluetoothDevice device) async {
    setState(() {
      bluetoothStatus = 'Connecting...';
    });

    try {
      print('Connecting to Bluetooth device: ${device.platformName}');

      // First ensure any previous connections are closed
      try {
        await device.disconnect();
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        // Ignore errors - just make sure we're starting fresh
      }

      // Connect with faster timeout
      await device.connect(
        timeout: const Duration(seconds: 5),
        autoConnect: false,
      );

      print('Connected, discovering services...');

      // Add a short delay before discovering services
      await Future.delayed(const Duration(milliseconds: 500));

      List<BluetoothService> services = await device.discoverServices();
      print('Found ${services.length} services');

      BluetoothService? espService;
      BluetoothCharacteristic? txChar;

      // Look for our service and characteristic - use a more flexible match
      for (var service in services) {
        print('Checking service: ${service.uuid}');
        if (service.uuid.toString().toUpperCase().contains(
          ESP32_SERVICE_UUID.substring(0, 8),
        )) {
          espService = service;
          print('Found ESP32 service!');

          for (var characteristic in service.characteristics) {
            print('Checking characteristic: ${characteristic.uuid}');
            if (characteristic.uuid.toString().toUpperCase().contains(
              ESP32_CHARACTERISTIC_UUID.substring(0, 8),
            ) &&
                characteristic.properties.write) {
              txChar = characteristic;
              print('Found TX characteristic!');
              break;
            }
          }
          break;
        }
      }

      if (txChar != null) {
        setState(() {
          bluetoothDevice = device;
          txCharacteristic = txChar;
          bluetoothStatus = 'Connected';
          isBluetoothConnected = true;
        });

        // Send a test command to verify connection
        await Future.delayed(const Duration(milliseconds: 500));
        try {
          List<int> testCmd = utf8.encode('STOP:0');
          // OPTIMIZATION: Use withoutResponse for lower latency
          await txChar.write(testCmd, withoutResponse: true);
          print('Initial STOP command sent successfully');
        } catch (e) {
          print('ERROR sending initial command: $e');
        }
      } else {
        print('Required service or characteristic not found');
        await device.disconnect();
        setState(() {
          bluetoothStatus = 'Service not found';
          isBluetoothConnected = false;
        });
      }
    } catch (e) {
      print('Bluetooth connection error: $e');
      setState(() {
        bluetoothStatus = 'Failed';
        isBluetoothConnected = false;
      });
    }
  }

  // Improved disconnection
  void disconnectBluetooth() async {
    // First send a STOP command
    if (isBluetoothConnected && txCharacteristic != null) {
      try {
        final stopCmd = _commandCache['STOP:0'] ?? utf8.encode('STOP:0');
        txCharacteristic!.write(stopCmd, withoutResponse: true);
      } catch (e) {
        // Ignore errors during disconnect
      }
    }

    scanSubscription?.cancel();
    scanSubscription = null;

    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      // Ignore errors
    }

    if (bluetoothDevice != null) {
      try {
        await bluetoothDevice!.disconnect();
      } catch (e) {
        // Ignore errors
      }

      setState(() {
        bluetoothDevice = null;
        txCharacteristic = null;
        isBluetoothConnected = false;
        bluetoothStatus = 'Disconnected';
      });
    }
  }

  // Disconnect WiFi
  void disconnectWiFi() {
    if (wifiChannel != null) {
      wifiChannel!.sink.close();
      wifiChannel = null;

      setState(() {
        isWifiConnected = false;
        wifiStatus = 'Disconnected';
      });
    }
  }

  // OPTIMIZED: Send command with reduced throttling interval and double-send
  void sendCommandWithThrottle(String command) {
    // Always send STOP commands immediately
    if (command.startsWith('STOP')) {
      _lastSentCommand = command;
      _lastCommandTime = DateTime.now().millisecondsSinceEpoch;
      sendCommand(command);
      // OPTIMIZATION: Send stop commands twice for reliability
      Future.delayed(const Duration(milliseconds: 2), () {
        sendCommand(command);
      });
      return;
    }

    // For rotation commands, use zero throttling
    if (command.startsWith('ROTATE')) {
      _lastSentCommand = command;
      _lastCommandTime = DateTime.now().millisecondsSinceEpoch;
      sendRotationCommand(command);
      return;
    }

    // OPTIMIZATION: Throttle other commands with reduced 5ms interval
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    if (command != _lastSentCommand ||
        (currentTime - _lastCommandTime) > _minCommandInterval) {
      _lastSentCommand = command;
      _lastCommandTime = currentTime;
      sendCommand(command);
    }
  }

  // OPTIMIZATION: Direct command sending without any checks
  void _sendDirectCommand(String command) {
    if (isBluetoothConnected && txCharacteristic != null) {
      try {
        List<int> encodedCommand = _commandCache[command] ?? utf8.encode(command);
        txCharacteristic!.write(encodedCommand, withoutResponse: true);
      } catch (e) {
        // Fallback to WiFi silently
        if (isWifiConnected && wifiChannel != null) {
          wifiChannel!.sink.add(command);
        }
      }
    } else if (isWifiConnected && wifiChannel != null) {
      wifiChannel!.sink.add(command);
    }
  }

  // OPTIMIZED: Rotation command sending with high priority
  void sendRotationCommand(String command) {
    print('Sending rotation command: $command');

    // Add to priority queue for guaranteed execution
    _priorityCommands.add(command);

    // Also send now for immediate response
    if (isBluetoothConnected && txCharacteristic != null) {
      try {
        List<int> encodedCommand = _commandCache[command] ?? utf8.encode(command);
        // OPTIMIZATION: Use withoutResponse for lower latency
        txCharacteristic!.write(encodedCommand, withoutResponse: true);
      } catch (e) {
        if (isWifiConnected && wifiChannel != null) {
          wifiChannel!.sink.add(command);
        }
      }
    } else if (isWifiConnected && wifiChannel != null) {
      wifiChannel!.sink.add(command);
    }
  }

  // OPTIMIZED: Command sending with reduced overhead
  void sendCommand(String command) {
    if (isBluetoothConnected && txCharacteristic != null) {
      try {
        List<int> encodedCommand = _commandCache[command] ?? utf8.encode(command);
        // OPTIMIZATION: Use withoutResponse for lower latency
        txCharacteristic!.write(encodedCommand, withoutResponse: true);
      } catch (e) {
        // Fallback to WiFi if Bluetooth fails
        if (isWifiConnected && wifiChannel != null) {
          wifiChannel!.sink.add(command);
        }
      }
    } else if (isWifiConnected && wifiChannel != null) {
      wifiChannel!.sink.add(command);
    }
  }

  void stopCar() {
    // Always send stop commands immediately
    sendCommand('STOP:0');
    _lastCommand = 'STOP';
    _lastSentCommand = 'STOP:0';
    _lastCommandTime = DateTime.now().millisecondsSinceEpoch;
    _isButtonPressed = false;

    // OPTIMIZATION: Send stop command twice with slight delay for reliability
    Future.delayed(const Duration(milliseconds: 2), () {
      sendCommand('STOP:0');
    });
  }

  // Handle directional button press
  void handleDirectionButtonPress(String command) {
    _lastCommand = command;
    _isButtonPressed = true;
    sendCommandWithThrottle('$command:$_currentSpeed');
  }

  // Handle directional button release
  void handleDirectionButtonRelease() {
    stopCar();
  }

  // OPTIMIZED: Rotation handling with double-send
  void handleRotationPress(String command) {
    _lastCommand = command;
    _isButtonPressed = true;

    // Skip throttling for rotation commands
    String fullCommand = '$command:$_rotationSpeed';
    _lastSentCommand = fullCommand;
    _lastCommandTime = DateTime.now().millisecondsSinceEpoch;

    // OPTIMIZATION: Send rotation command twice for reliability
    sendRotationCommand(fullCommand);
    Future.delayed(const Duration(milliseconds: 2), () {
      sendRotationCommand(fullCommand);
    });
  }

  @override
  void dispose() {
    stopCar();
    wifiChannel?.sink.close();
    disconnectBluetooth();
    scanSubscription?.cancel();
    _priorityCommandTimer?.cancel();
    super.dispose();
  }

  // UI Components - with larger rotation buttons
  Widget buildDirectionalPad() {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // Center indicator
          Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Forward button (↑)
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: _buildDirectionButton(
                icon: Icons.arrow_upward,
                onPressed: () => handleDirectionButtonPress('FORWARD'),
                onReleased: handleDirectionButtonRelease,
              ),
            ),
          ),

          // Backward button (↓)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: _buildDirectionButton(
                icon: Icons.arrow_downward,
                onPressed: () => handleDirectionButtonPress('BACKWARD'),
                onReleased: handleDirectionButtonRelease,
              ),
            ),
          ),

          // Left button (←)
          Positioned(
            left: 20,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildDirectionButton(
                icon: Icons.arrow_back,
                onPressed: () => handleDirectionButtonPress('SIDEWAYS_LEFT'),
                onReleased: handleDirectionButtonRelease,
              ),
            ),
          ),

          // Right button (→)
          Positioned(
            right: 20,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildDirectionButton(
                icon: Icons.arrow_forward,
                onPressed: () => handleDirectionButtonPress('SIDEWAYS_RIGHT'),
                onReleased: handleDirectionButtonRelease,
              ),
            ),
          ),

          // Diagonal - Top Left (↖)
          Positioned(
            top: 40,
            left: 40,
            child: _buildDirectionButton(
              icon: Icons.arrow_back,
              iconRotation: -45,
              onPressed: () => handleDirectionButtonPress('DIAGONAL_LEFT'),
              onReleased: handleDirectionButtonRelease,
            ),
          ),

          // Diagonal - Top Right (↗)
          Positioned(
            top: 40,
            right: 40,
            child: _buildDirectionButton(
              icon: Icons.arrow_forward,
              iconRotation: 45,
              onPressed: () => handleDirectionButtonPress('DIAGONAL_RIGHT'),
              onReleased: handleDirectionButtonRelease,
            ),
          ),

          // Diagonal - Bottom Left (↙)
          Positioned(
            bottom: 40,
            left: 40,
            child: _buildDirectionButton(
              icon: Icons.arrow_back,
              iconRotation: 45,
              onPressed: () => handleDirectionButtonPress('DIAGONAL_BACK_LEFT'),
              onReleased: handleDirectionButtonRelease,
            ),
          ),

          // Diagonal - Bottom Right (↘)
          Positioned(
            bottom: 40,
            right: 40,
            child: _buildDirectionButton(
              icon: Icons.arrow_forward,
              iconRotation: -45,
              onPressed:
                  () => handleDirectionButtonPress('DIAGONAL_BACK_RIGHT'),
              onReleased: handleDirectionButtonRelease,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build direction buttons
  Widget _buildDirectionButton({
    required IconData icon,
    double iconRotation = 0,
    required VoidCallback onPressed,
    required VoidCallback onReleased,
  }) {
    return GestureDetector(
      onTapDown: (_) => onPressed(),
      onTapUp: (_) => onReleased(),
      onTapCancel: onReleased,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Transform.rotate(
          angle: iconRotation * 3.14159 / 180,
          child: Icon(icon, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  // Speed control slider
  Widget buildSpeedControl() {
    return Container(
      width: 50,
      height: 280,
      margin: const EdgeInsets.only(left: 15),
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Speed label
          RotatedBox(
            quarterTurns: 1,
            child: Text(
              'SPEED',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ),

          // Speed value in numeric display
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '$_currentSpeed',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _isButtonPressed ? Colors.green : Colors.black54,
              ),
            ),
          ),

          // Vertical slider for speed control
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: Slider(
                value: _currentSpeed.toDouble(),
                min: 50,
                max: 255,
                divisions: 41, // 255-50 / 5 = 41 steps
                onChanged: (value) {
                  setState(() {
                    _currentSpeed = value.round();
                    // Update command if a button is currently pressed and it's not a rotation command
                    if (_isButtonPressed &&
                        _lastCommand != 'ROTATE_LEFT_CORNER' &&
                        _lastCommand != 'ROTATE_RIGHT_CORNER' &&
                        _lastCommand != 'ROTATE_CENTER_CCW' &&
                        _lastCommand != 'ROTATE_CENTER_CW') {
                      sendCommandWithThrottle('$_lastCommand:$_currentSpeed');
                    }
                  });
                },
              ),
            ),
          ),

          // Min/Max indicators
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'max',
                style: TextStyle(fontSize: 10, color: Colors.black54),
              ),
              Icon(Icons.arrow_upward, size: 16, color: Colors.black54),
            ],
          ),
        ],
      ),
    );
  }

  // Build rotation button with fixed speed - LARGER SIZE
  Widget buildRotationButton(String command, IconData icon) {
    return Stack(
      children: [
        GestureDetector(
          onTapDown: (_) => handleRotationPress(command),
          onTapUp: (_) => stopCar(),
          onTapCancel: () => stopCar(),
          child: Container(
            width: 85, // Increased from 65
            height: 85, // Increased from 65
            margin: const EdgeInsets.all(5),
            child: ElevatedButton(
              onPressed: null, // Handled by GestureDetector
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(4),
                backgroundColor: Colors.green, // Green for fixed-speed buttons
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10), // Slightly larger radius
                ),
              ),
              child: Icon(icon, size: 36), // Increased from 28
            ),
          ),
        ),
        // Speed display on rotation buttons
        Positioned(
          right: 10,
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '$_rotationSpeed',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12, // Slightly larger font
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Build rotation controls with adjusted spacing
  Widget buildRotationControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top row - Corner rotation buttons
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildRotationButton('ROTATE_LEFT_CORNER', Icons.turn_slight_left),
            const SizedBox(width: 20), // Increased from 15
            buildRotationButton('ROTATE_RIGHT_CORNER', Icons.turn_slight_right),
          ],
        ),
        const SizedBox(height: 20), // Increased from 15
        // Bottom row - In-place rotation buttons
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildRotationButton('ROTATE_CENTER_CCW', Icons.rotate_left),
            const SizedBox(width: 20), // Increased from 15
            buildRotationButton('ROTATE_CENTER_CW', Icons.rotate_right),
          ],
        ),
      ],
    );
  }

  // Compact connection status widget
  Widget buildCompactConnectionStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // WiFi status
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi,
                color: isWifiConnected ? Colors.green : Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                wifiStatus,
                style: TextStyle(
                  color: isWifiConnected ? Colors.green : Colors.black,
                  fontSize: 12,
                ),
              ),
              IconButton(
                iconSize: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  isWifiConnected ? Icons.link_off : Icons.link,
                  size: 16,
                ),
                onPressed: isWifiConnected ? disconnectWiFi : connectWiFi,
              ),
            ],
          ),

          const SizedBox(width: 8),
          const Text('|', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(width: 8),

          // Bluetooth status
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bluetooth,
                color: isBluetoothConnected ? Colors.green : Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                bluetoothStatus,
                style: TextStyle(
                  color: isBluetoothConnected ? Colors.green : Colors.black,
                  fontSize: 12,
                ),
              ),
              IconButton(
                iconSize: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  isBluetoothConnected
                      ? Icons.bluetooth_disabled
                      : Icons.bluetooth_searching,
                  size: 16,
                ),
                onPressed:
                isBluetoothConnected
                    ? disconnectBluetooth
                    : () {
                  showDialog(
                    context: context,
                    builder:
                        (context) => buildBluetoothDeviceSelector(),
                  );
                },
              ),
            ],
          ),

          const SizedBox(width: 8),
          const Text('|', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(width: 8),

          // Command display
          Text(
            _lastCommand,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // Bluetooth device selector dialog
  Widget buildBluetoothDeviceSelector() {
    return AlertDialog(
      title: const Text('Select Bluetooth Device'),
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      content: SizedBox(
        width: 300,
        height: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Devices',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: isScanning ? null : startBluetoothScan,
                ),
              ],
            ),
            const Divider(),
            isScanning
                ? const Center(child: CircularProgressIndicator())
                : Expanded(
              child:
              scanResults.isEmpty
                  ? const Center(child: Text('No devices found'))
                  : ListView.builder(
                itemCount: scanResults.length,
                itemBuilder: (context, index) {
                  final device = scanResults[index].device;
                  final name =
                  device.platformName.isNotEmpty
                      ? device.platformName
                      : 'Unknown Device';

                  return ListTile(
                    dense: true,
                    title: Text(name),
                    subtitle: Text(device.remoteId.toString()),
                    trailing: TextButton(
                      child: const Text('Connect'),
                      onPressed: () {
                        connectToBluetoothDevice(device);
                        Navigator.of(context).pop();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Control'),
        titleSpacing: 0,
        toolbarHeight: 40, // Reduced height
        centerTitle: true,
        actions: [buildCompactConnectionStatus(), const SizedBox(width: 8)],
      ),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Controls section - directional pad and speed slider side by side
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [buildDirectionalPad(), buildSpeedControl()],
            ),

            // Rotation Controls
            buildRotationControls(),
          ],
        ),
      ),
    );
  }
}