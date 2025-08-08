import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

void main() {
  runApp(
    MaterialApp(
      home: MotorControlScreen(),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
    ),
  );
}

class MotorController {
  WebSocketChannel? _channel;
  bool _connected = false;
  final String ip;
  Function(String)? onStatusUpdate;
  Function(bool)? onConnectionChange;

  MotorController(this.ip);

  bool get isConnected => _connected;

  Future<bool> connect() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse('ws://$ip:81'));
      _connected = true;
      if (onConnectionChange != null) {
        onConnectionChange!(true);
      }

      // Setup listener
      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            if (data['status'] != null && onStatusUpdate != null) {
              onStatusUpdate!(data['status']);
            }
          } catch (e) {
            print('Error parsing message: $e');
          }
        },
        onDone: () {
          _connected = false;
          if (onConnectionChange != null) {
            onConnectionChange!(false);
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          _connected = false;
          if (onConnectionChange != null) {
            onConnectionChange!(false);
          }
        },
      );

      return true;
    } catch (e) {
      print('Connection error: $e');
      _connected = false;
      if (onConnectionChange != null) {
        onConnectionChange!(false);
      }
      return false;
    }
  }

  void toggleLineDetection(bool enabled) {
    if (_connected) {
      _channel!.sink.add(jsonEncode({'lineDetection': enabled}));
    }
  }

  void sendManualCommand(String command) {
    if (_connected) {
      _channel!.sink.add(jsonEncode({'command': command}));
    }
  }

  void sendMotorSpeeds(int leftSpeed, int rightSpeed) {
    if (_connected) {
      _channel!.sink.add(jsonEncode({'left': leftSpeed, 'right': rightSpeed}));
    }
  }

  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close();
      _connected = false;
    }
  }
}

class MotorControlScreen extends StatefulWidget {
  @override
  _MotorControlScreenState createState() => _MotorControlScreenState();
}

class _MotorControlScreenState extends State<MotorControlScreen> {
  final String espIP = "192.168.4.1"; // Default IP for the ESP8266 AP
  late MotorController controller;
  String status = 'Disconnected';
  bool isConnected = false;
  bool lineDetectionEnabled = false;
  TextEditingController ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    ipController.text = espIP;
    controller = MotorController(espIP);
    controller.onStatusUpdate = (newStatus) {
      setState(() {
        status = newStatus;
      });
    };
    controller.onConnectionChange = (connected) {
      setState(() {
        isConnected = connected;
        if (!connected) {
          status = 'Disconnected';
        }
      });
    };
  }

  @override
  void dispose() {
    controller.disconnect();
    ipController.dispose();
    super.dispose();
  }

  void connect() async {
    setState(() {
      status = 'Connecting...';
    });

    controller = MotorController(ipController.text);
    controller.onStatusUpdate = (newStatus) {
      setState(() {
        status = newStatus;
      });
    };
    controller.onConnectionChange = (connected) {
      setState(() {
        isConnected = connected;
        if (!connected) {
          status = 'Disconnected';
        }
      });
    };

    bool success = await controller.connect();
    if (!success) {
      setState(() {
        status = 'Connection failed';
      });
    }
  }

  void onButtonPressed(String command) {
    if (!isConnected) return;

    controller.sendManualCommand(command);
    setState(() {
      status = 'Sent: $command';
    });
  }

  void toggleLineDetection() {
    if (!isConnected) return;

    setState(() {
      lineDetectionEnabled = !lineDetectionEnabled;
    });
    controller.toggleLineDetection(lineDetectionEnabled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Line Follower Control'), centerTitle: true),
      body: Column(
        children: [
          // Connection setup
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ipController,
                    decoration: InputDecoration(
                      labelText: 'ESP8266 IP Address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: isConnected ? null : connect,
                  child: Text(isConnected ? 'Connected' : 'Connect'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConnected ? Colors.green : null,
                  ),
                ),
              ],
            ),
          ),

          // Status and mode
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              children: [
                Text(
                  'Status: $status',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Line Detection Mode: '),
                    Switch(
                      value: lineDetectionEnabled,
                      onChanged:
                          isConnected ? (value) => toggleLineDetection() : null,
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(),

          // Manual control panel
          Expanded(
            child: Center(
              child: Opacity(
                opacity: lineDetectionEnabled ? 0.5 : 1.0,
                child: AbsorbPointer(
                  absorbing: lineDetectionEnabled,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Manual Control',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 20),
                      // Forward button
                      GestureDetector(
                        onTapDown: (_) => onButtonPressed("FORWARD"),
                        onTapUp: (_) => onButtonPressed("STOP"),
                        onTapCancel: () => onButtonPressed("STOP"),
                        child: ControlButton(
                          text: 'Forward',
                          icon: Icons.arrow_upward,
                        ),
                      ),
                      SizedBox(height: 16),
                      // Left, Stop, Right buttons row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          GestureDetector(
                            onTapDown: (_) => onButtonPressed("LEFT"),
                            onTapUp: (_) => onButtonPressed("STOP"),
                            onTapCancel: () => onButtonPressed("STOP"),
                            child: ControlButton(
                              text: 'Left',
                              icon: Icons.arrow_back,
                            ),
                          ),
                          GestureDetector(
                            onTapDown: (_) => onButtonPressed("STOP"),
                            child: ControlButton(
                              text: 'Stop',
                              icon: Icons.stop,
                              color: Colors.red,
                            ),
                          ),
                          GestureDetector(
                            onTapDown: (_) => onButtonPressed("RIGHT"),
                            onTapUp: (_) => onButtonPressed("STOP"),
                            onTapCancel: () => onButtonPressed("STOP"),
                            child: ControlButton(
                              text: 'Right',
                              icon: Icons.arrow_forward,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      // Backward button
                      GestureDetector(
                        onTapDown: (_) => onButtonPressed("BACKWARD"),
                        onTapUp: (_) => onButtonPressed("STOP"),
                        onTapCancel: () => onButtonPressed("STOP"),
                        child: ControlButton(
                          text: 'Backward',
                          icon: Icons.arrow_downward,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ControlButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color? color;

  const ControlButton({required this.text, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
