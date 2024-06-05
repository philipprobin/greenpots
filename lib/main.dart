import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'dart:async';

import 'esp_controller.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WiFiConnectScreen(),
    );
  }
}

class WiFiConnectScreen extends StatefulWidget {
  const WiFiConnectScreen({super.key});

  @override
  _WiFiConnectScreenState createState() => _WiFiConnectScreenState();
}

class _WiFiConnectScreenState extends State<WiFiConnectScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final ESP8266Controller espController =
      ESP8266Controller("http://192.168.4.1");

  String? _selectedNetwork;
  List<WifiNetwork> _wifiNetworks = [];
  String _statusMessage = '';
  String _sensorValue = '';
  bool _isConnecting = false;
  bool isConnected = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scanForWiFiNetworks();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scanForWiFiNetworks() async {
    var status = await Permission.location.request();
    debugPrint("Location permission status: $status");
    if (status.isGranted) {
      bool? isEnabled = await WiFiForIoTPlugin.isEnabled();
      debugPrint("WiFi enabled: $isEnabled");
      if (isEnabled) {
        List<WifiNetwork> networks = await WiFiForIoTPlugin.loadWifiList();
        if (networks.isNotEmpty) {
          setState(() {
            _wifiNetworks = networks.toSet().toList(); // Remove duplicates
            _selectedNetwork =
                '${_wifiNetworks[0].ssid} (${_wifiNetworks[0].bssid})'; // Set default network to the first one
          });
        } else {
          setState(() {
            _statusMessage = 'No networks found';
          });
        }
      } else {
        setState(() {
          _statusMessage = 'WiFi is not enabled';
        });
      }
    } else {
      setState(() {
        _statusMessage = 'Location permission is required';
      });
    }
  }

  void _connectToWiFi() async {
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Trying to connect...';
    });

    String ssid = _selectedNetwork?.split(' (').first ?? '';
    String password = _passwordController.text;
    String message = await espController.connectToWiFi(ssid, password);

    setState(() {
      _statusMessage = message;
    });

    if (message == 'Trying to connect...') {
      _checkConnectionStatus();
    } else {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  void _checkConnectionStatus() async {
    var status = await espController.checkConnectionStatus();
    setState(() {
      if (status['status'] == 'connected') {
        _sensorValue = status['value'];
        _statusMessage = 'Connected to WiFi and sensor value received';
        isConnected = true;
        _startSensorValueUpdates();
      } else {
        _statusMessage = status['message'];
        isConnected = false;
      }
      _isConnecting = false;
    });
  }

  void _startSensorValueUpdates() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      String value = await espController.readSensorValue(isConnected);
      setState(() {
        _sensorValue = value;
      });
    });
  }

  String _convertToPercents() {
    if (_sensorValue.isEmpty) return "";

    // Parse the sensor value to an integer
    int sensorValueInt = int.tryParse(_sensorValue) ?? 0;

    // Calculate the percentage
    const int maxHumidityValue = 343;
    const int minHumidityValue = 762;

    int percentage = ((sensorValueInt - minHumidityValue) * 100) ~/
        (maxHumidityValue - minHumidityValue);
    percentage = percentage.clamp(0, 100); // Ensure the value is within 0-100%
    return '$percentage%';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GreenPots',
            style: TextStyle(
                color: Colors.green,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedNetwork,
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedNetwork = newValue;
                        });
                      },
                      items: _wifiNetworks
                          .map<DropdownMenuItem<String>>((WifiNetwork value) {
                        return DropdownMenuItem<String>(
                          value: '${value.ssid} (${value.bssid})',
                          child: Text('${value.ssid} (${value.bssid})'),
                        );
                      }).toList(),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _scanForWiFiNetworks();
                    },
                    child: const Text('Refresh'),
                  ),
                ],
              ),

              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _isConnecting
                      ? const CircularProgressIndicator() // Show spinner while connecting
                      : ElevatedButton(
                          onPressed: _connectToWiFi,
                          child: const Text('Connect'),
                        ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                _statusMessage,
                style: const TextStyle(fontSize: 16, color: Colors.blue),
              ),
              const SizedBox(height: 20),
              Text(
                'Sensor Percentage: ${_convertToPercents()}',
                style: const TextStyle(fontSize: 16, color: Colors.green),
              ),
              const SizedBox(height: 20),
              Text(
                'Sensor Value: $_sensorValue',
                style: const TextStyle(fontSize: 16, color: Colors.green),
              ),
              const SizedBox(height: 20),
              Container(
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Anleitung',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Verbinde das ESP Modul mit dem Strom \n2. Verbinde dein Handy mit ESP_AP Password: 12345678 \n3. Öffne die App und gebe die SSID und das Passwort deines Heimwlans ein \n4. Klicke auf Connect',
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
