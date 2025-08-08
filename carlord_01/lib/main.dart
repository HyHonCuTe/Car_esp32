import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ================ INTERFACE CONTROL SETTINGS ================
class ControllerConfig {
  // Connection settings
  static const String wifiIP = "192.168.4.1";
  static const int webSocketPort = 81;

  // Layout settings 
  static const bool forceLandscape = true;
  static const double buttonSpacing = 15.0;     // Reduced spacing
  static const double topPadding = 10.0;        // Increased to push up when no app bar
  static const double leftEdgePadding = 75.0;
  static const double rightControlsTopPadding = 50.0;

  // Button appearance
  static const double buttonSize = 90.0;        // Reduced from 100 to prevent overflow
  static const double iconSize = 36.0;          // Adjusted accordingly
  static const double fontSize = 16.0;
  static const double buttonRadius = 10.0;

  // Colors
  static const Color primaryColor = Colors.blue;
  static const Color buttonTextColor = Colors.white;
  static const Color backgroundColor = Colors.white;
  static const Color statusTextColor = Colors.black;

  // Speed control
  static const double minSpeed = 0;
  static const double maxSpeed = 255;
  static const double initialSpeed = 180;

  // User info
  static const String username = "HiepvHo";
  static const String timestamp = "2025-04-03 10:23:03";  // Updated timestamp

  // Display settings
  static const bool showStatusBar = true;
  static const double statusFontSize = 14.0;
  static const double sliderHeight = 60.0;      // Fixed height for slider
}
// ==========================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (ControllerConfig.forceLandscape) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  runApp(MaterialApp(
    title: 'Car Controller',
    theme: ThemeData(primarySwatch: Colors.blue),
    home: MotorControlScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class MotorController {
  final WebSocketChannel channel;

  MotorController(String ip, int port)
      : channel = WebSocketChannel.connect(Uri.parse('ws://$ip:$port'));

  void sendCommand(String command) {
    channel.sink.add(command);
  }

  void dispose() {
    channel.sink.close();
  }
}

class MotorControlScreen extends StatefulWidget {
  @override
  _MotorControlScreenState createState() => _MotorControlScreenState();
}

class _MotorControlScreenState extends State<MotorControlScreen> {
  late MotorController controller;
  String status = 'Ready';
  double currentSpeed = ControllerConfig.initialSpeed;

  @override
  void initState() {
    super.initState();
    controller = MotorController(
        ControllerConfig.wifiIP,
        ControllerConfig.webSocketPort
    );

    // Initialize with default speed
    Future.delayed(Duration(milliseconds: 500), () {
      sendSpeedCommand(currentSpeed.toInt());
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void onForwardPressed() {
    controller.sendCommand("FORWARD");
    setState(() => status = 'Moving Forward');
  }

  void onBackwardPressed() {
    controller.sendCommand("BACKWARD");
    setState(() => status = 'Moving Backward');
  }

  void onLeftPressed() {
    controller.sendCommand("LEFT");
    setState(() => status = 'Turning Left');
  }

  void onRightPressed() {
    controller.sendCommand("RIGHT");
    setState(() => status = 'Turning Right');
  }

  void onDirectionReleased() {
    controller.sendCommand("CENTER");
    setState(() => status = 'Wheel Centered');
  }

  void onMovementReleased() {
    controller.sendCommand("STOP");
    setState(() => status = 'Stopped');
  }

  void sendSpeedCommand(int speed) {
    controller.sendCommand("SPEED:$speed");
    setState(() => status = 'Speed: $speed');
  }

  @override
  Widget build(BuildContext context) {
    // Add extra top padding to account for status bar when app bar is removed
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: ControllerConfig.backgroundColor,
      // App bar removed completely
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(2.0, 0, 2.0, 2.0),
          child: Column(
            children: [
              // Status bar (optional)
              if (ControllerConfig.showStatusBar)
                Container(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    'Status: $status',
                    style: TextStyle(
                      fontSize: ControllerConfig.statusFontSize,
                      fontWeight: FontWeight.bold,
                      color: ControllerConfig.statusTextColor,
                    ),
                  ),
                ),

              // Main control area - made more compact
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT SIDE - Forward/Backward Controls
                    Padding(
                      padding: EdgeInsets.only(
                          left: ControllerConfig.leftEdgePadding,
                          top: ControllerConfig.topPadding
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Forward button
                          ControlButton(
                            text: 'Forward',
                            icon: Icons.arrow_upward,
                            onTapDown: onForwardPressed,
                            onTapUp: onMovementReleased,
                            onTapCancel: onMovementReleased,
                            size: ControllerConfig.buttonSize,
                            iconSize: ControllerConfig.iconSize,
                            fontSize: ControllerConfig.fontSize,
                            color: ControllerConfig.primaryColor,
                            textColor: ControllerConfig.buttonTextColor,
                            radius: ControllerConfig.buttonRadius,
                          ),
                          SizedBox(height: ControllerConfig.buttonSpacing),
                          // Backward button
                          ControlButton(
                            text: 'Backward',
                            icon: Icons.arrow_downward,
                            onTapDown: onBackwardPressed,
                            onTapUp: onMovementReleased,
                            onTapCancel: onMovementReleased,
                            size: ControllerConfig.buttonSize,
                            iconSize: ControllerConfig.iconSize,
                            fontSize: ControllerConfig.fontSize,
                            color: ControllerConfig.primaryColor,
                            textColor: ControllerConfig.buttonTextColor,
                            radius: ControllerConfig.buttonRadius,
                          ),
                        ],
                      ),
                    ),

                    // RIGHT SIDE - Left/Right Controls
                    Padding(
                      padding: EdgeInsets.only(
                          right: ControllerConfig.leftEdgePadding,
                          top: ControllerConfig.rightControlsTopPadding
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ControlButton(
                            text: 'Left',
                            icon: Icons.arrow_back,
                            onTapDown: onLeftPressed,
                            onTapUp: onDirectionReleased,
                            onTapCancel: onDirectionReleased,
                            size: ControllerConfig.buttonSize,
                            iconSize: ControllerConfig.iconSize,
                            fontSize: ControllerConfig.fontSize,
                            color: ControllerConfig.primaryColor,
                            textColor: ControllerConfig.buttonTextColor,
                            radius: ControllerConfig.buttonRadius,
                          ),
                          SizedBox(width: ControllerConfig.buttonSpacing),
                          ControlButton(
                            text: 'Right',
                            icon: Icons.arrow_forward,
                            onTapDown: onRightPressed,
                            onTapUp: onDirectionReleased,
                            onTapCancel: onDirectionReleased,
                            size: ControllerConfig.buttonSize,
                            iconSize: ControllerConfig.iconSize,
                            fontSize: ControllerConfig.fontSize,
                            color: ControllerConfig.primaryColor,
                            textColor: ControllerConfig.buttonTextColor,
                            radius: ControllerConfig.buttonRadius,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Speed Slider - fixed height to prevent overflow
              Container(
                height: ControllerConfig.sliderHeight,
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Speed value
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                          '${currentSpeed.toInt()}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 5,
                              color: ControllerConfig.primaryColor
                          )
                      ),
                    ),
                    // Slider
                    Row(
                      children: [
                        Icon(Icons.speed_outlined, size: 18,
                            color: this.currentSpeed < 85 ? Colors.grey : Colors.orange),
                        Expanded(
                          child: Slider(
                            value: currentSpeed,
                            min: ControllerConfig.minSpeed,
                            max: ControllerConfig.maxSpeed,
                            activeColor: ControllerConfig.primaryColor,
                            onChanged: (value) {
                              setState(() {
                                currentSpeed = value;
                              });
                            },
                            onChangeEnd: (value) {
                              sendSpeedCommand(value.toInt());
                            },
                          ),
                        ),
                        Icon(Icons.speed, size: 20,
                            color: this.currentSpeed < 170 ? Colors.grey : Colors.red),
                      ],
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

class ControlButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;
  final VoidCallback onTapCancel;
  final double size;
  final double iconSize;
  final double fontSize;
  final Color color;
  final Color textColor;
  final double radius;

  const ControlButton({
    required this.text,
    required this.icon,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
    required this.size,
    required this.iconSize,
    required this.fontSize,
    required this.color,
    required this.textColor,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: onTapCancel,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              offset: Offset(0, 2),
              blurRadius: 4.0,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: iconSize),
            SizedBox(height: 4),
            Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}