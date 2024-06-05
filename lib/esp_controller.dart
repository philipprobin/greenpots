
import 'dart:convert';

import 'package:http/http.dart' as http;

class ESP8266Controller {
  final String espUrl;

  ESP8266Controller(this.espUrl);

  Future<String> connectToWiFi(String ssid, String password) async {
    try {
      var response = await http.post(
        Uri.parse('$espUrl/connect'),
        body: {'ssid': ssid, 'password': password},
      );
      if (response.statusCode == 200) {
        return 'Trying to connect...';
      } else {
        return 'Failed to send request to ESP';
      }
    } on Exception {
      return 'Connection timed out. Please try again.';
    } catch (error) {
      return 'Error connecting to WiFi: $error';
    }
  }

  Future<Map<String, dynamic>> checkConnectionStatus() async {
    await Future.delayed(const Duration(seconds: 5)); // Wait for the ESP to connect

    try {
      var response = await http.get(Uri.parse('$espUrl/status'));
      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        return {'status': 'connected', 'value': jsonResponse['value'].toString()};
      } else {
        return {'status': 'failed', 'message': 'Failed to check connection status'};
      }
    } on Exception {
      return {'status': 'failed', 'message': 'Connection timed out. Please try again.'};
    } catch (error) {
      return {'status': 'failed', 'message': 'Error checking connection status: $error'};
    }
  }

  Future<String> readSensorValue(bool isConnected) async {
    if (!isConnected) {
      return 'Not connected to WiFi';
    }

    try {
      var response = await http.get(Uri.parse('$espUrl/sensor_stream'));
      if (response.statusCode == 200) {
        return response.body;
      } else {
        return 'Failed to read sensor value';
      }
    } on Exception catch (error) {
      return 'Error reading sensor value: $error';
    }
  }
}