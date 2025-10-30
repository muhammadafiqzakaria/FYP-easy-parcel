import 'package:http/http.dart' as http;
import 'dart:convert';

class ESP32Service {
  static const String esp32IP = "10.59.125.229";
  static const int timeoutSeconds = 5;

  // Test connection to ESP32
  static Future<void> testConnection() async {
    print('🧪 Testing ESP32 connection...');
    try {
      final response = await http
          .get(
            Uri.parse('http://$esp32IP/'),
          )
          .timeout(const Duration(seconds: 3));
      print('✅ Basic connection test: ${response.statusCode}');
    } catch (e) {
      print('❌ Basic connection failed: $e');
    }
  }

  // Check if ESP32 is online
  static Future<bool> checkLockerStatus() async {
    try {
      print('🔍 Checking ESP32 status at http://$esp32IP/status');

      final response = await http
          .get(
            Uri.parse('http://$esp32IP/status'),
          )
          .timeout(const Duration(seconds: timeoutSeconds));

      print('📡 Status response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body);
          final isOnline = responseData['status'] == 'online';
          print(
              isOnline ? '✅ ESP32 is ONLINE' : '❌ ESP32 status is not online');
          return isOnline;
        } catch (e) {
          print('❌ JSON parsing error: $e');
          return false;
        }
      }
      return false;
    } catch (e) {
      print('❌ ESP32 connection error: $e');
      return false;
    }
  }

  static Future<bool> sendOTPToLocker(String otp, String lockerNumber) async {
    try {
      print('📤 Sending OTP $otp to locker $lockerNumber...');

      final response = await http
          .post(
            Uri.parse('http://$esp32IP/otp'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(
                {'otp': otp, 'locker': lockerNumber, 'action': 'unlock'}),
          )
          .timeout(const Duration(seconds: timeoutSeconds));

      print('📡 OTP response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body);
          final success = responseData['status'] == 'success';
          if (success) {
            print('✅ OTP sent successfully!');
          } else {
            print('❌ OTP send failed: ${responseData['message']}');
          }
          return success;
        } catch (e) {
          print('❌ JSON parsing error: $e');
          return false;
        }
      }
      return false;
    } catch (e) {
      print('❌ Error sending OTP: $e');
      return false;
    }
  }

  static Future<String?> getCurrentOTP() async {
    try {
      final response = await http
          .get(
            Uri.parse('http://$esp32IP/current_otp'),
          )
          .timeout(const Duration(seconds: timeoutSeconds));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['current_otp'];
      }
      return null;
    } catch (e) {
      print('❌ Error getting current OTP: $e');
      return null;
    }
  }
}
