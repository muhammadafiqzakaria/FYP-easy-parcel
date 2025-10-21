import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Easy Parcel',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Data Classes
class User {
  final String email;
  final String name;
  final String role;
  final String phoneNumber;

  const User({
    required this.email,
    required this.name,
    required this.role,
    required this.phoneNumber,
  });
}

class Parcel {
  final String id;
  final String studentName;
  final String lockerNumber;
  final String status;
  final String otp;

  const Parcel({
    required this.id,
    required this.studentName,
    required this.lockerNumber,
    required this.status,
    required this.otp,
  });
}

// ESP32 Network Service
class ESP32Service {
  static const String esp32IP = "10.213.193.229";
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

  // Send OTP to ESP32
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

  // Get current OTP from ESP32
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

// Mock Database
class MockDatabase {
  static final List<User> users = [
    const User(
      email: 'student@utp.edu.my',
      name: 'Ali Ahmad',
      role: 'student',
      phoneNumber: '012-3456789',
    ),
    const User(
      email: 'courier@utp.edu.my',
      name: 'Courier Staff',
      role: 'courier',
      phoneNumber: '012-9876543',
    ),
  ];

  static final List<Parcel> parcels = [
    const Parcel(
      id: '1',
      studentName: 'Ali Ahmad',
      lockerNumber: 'A101',
      status: 'delivered',
      otp: '123456',
    ),
    const Parcel(
      id: '2',
      studentName: 'Siti Sarah',
      lockerNumber: 'B202',
      status: 'delivered',
      otp: '654321',
    ),
  ];

  static User? currentUser;

  // Generate random OTP
  static String generateOTP() {
    return (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  String _name = '';
  String _phoneNumber = '';
  String _role = 'student';

  void _submit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (_isLogin) {
      // Mock login
      final user = MockDatabase.users.firstWhere(
        (user) => user.email == email,
        orElse: () =>
            const User(email: '', name: '', role: '', phoneNumber: ''),
      );

      if (user.email.isNotEmpty && password.isNotEmpty) {
        MockDatabase.currentUser = user;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => user.role == 'courier'
                ? const CourierHomeScreen()
                : const StudentHomeScreen(),
          ),
        );
      } else {
        _showError('Invalid email or password');
      }
    } else {
      // Mock signup
      if (email.isNotEmpty && password.isNotEmpty && _name.isNotEmpty) {
        final newUser = User(
          email: email,
          name: _name,
          role: _role,
          phoneNumber: _phoneNumber,
        );
        MockDatabase.users.add(newUser);
        MockDatabase.currentUser = newUser;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => _role == 'courier'
                ? const CourierHomeScreen()
                : const StudentHomeScreen(),
          ),
        );
      } else {
        _showError('Please fill all fields');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Easy Parcel'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const SizedBox(height: 20),
            Text(
              _isLogin ? 'Login' : 'Sign Up',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            if (!_isLogin) ...[
              TextFormField(
                decoration: const InputDecoration(labelText: 'Full Name'),
                onChanged: (value) => _name = value,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Phone Number'),
                onChanged: (value) => _phoneNumber = value,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _role,
                items: ['student', 'courier']
                    .map((role) => DropdownMenuItem(
                          value: role,
                          child: Text(role.toUpperCase()),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _role = value!),
                decoration: const InputDecoration(labelText: 'Role'),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _submit,
              child: Text(_isLogin ? 'LOGIN' : 'SIGN UP'),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => setState(() => _isLogin = !_isLogin),
              child: Text(_isLogin
                  ? 'Don\'t have an account? Sign up'
                  : 'Already have an account? Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  bool _isSendingOTP = false;
  bool _lockerOnline = false;
  bool _checkingStatus = false;

  @override
  void initState() {
    super.initState();
    _initializeConnection();
  }

  void _initializeConnection() {
    print('🚀 Initializing locker connection...');
    ESP32Service.testConnection();
    _checkLockerStatus();
    _startPeriodicStatusCheck();
  }

  void _startPeriodicStatusCheck() {
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        _checkLockerStatus();
        _startPeriodicStatusCheck();
      }
    });
  }

  Future<void> _checkLockerStatus() async {
    if (_checkingStatus) return;

    setState(() {
      _checkingStatus = true;
    });

    final online = await ESP32Service.checkLockerStatus();

    setState(() {
      _lockerOnline = online;
      _checkingStatus = false;
    });
  }

  Future<void> _sendOTPToHardware(
      String otp, String lockerNumber, String parcelId) async {
    setState(() {
      _isSendingOTP = true;
    });

    final success = await ESP32Service.sendOTPToLocker(otp, lockerNumber);

    setState(() {
      _isSendingOTP = false;
    });

    if (success) {
      _showSuccessDialog(otp, lockerNumber, parcelId); // Pass parcel ID
    } else {
      _showErrorDialog();
    }
  }

  void _showSuccessDialog(String otp, String lockerNumber, String parcelId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('OTP Sent Successfully!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('OTP has been sent to Locker $lockerNumber'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text(
                    'Go to the locker and enter:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    otp,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Locker: $lockerNumber',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'After collecting your parcel, scan the barcode',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Navigate to barcode scanner
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BarcodeScannerScreen(
                    parcelId: parcelId,
                    lockerNumber: lockerNumber,
                  ),
                ),
              );
            },
            child: const Text('Scan Barcode'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Connection Error'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not connect to the locker system. Please check:'),
            const SizedBox(height: 16),
            const Text('• ESP32 is powered ON'),
            const Text('• Both devices on same WiFi network'),
            const Text('• Correct IP address configured'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current ESP32 IP:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(ESP32Service.esp32IP),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _checkLockerStatus();
              },
              child: const Text('Retry Connection'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = MockDatabase.currentUser;
    final studentParcels =
        MockDatabase.parcels.where((p) => p.studentName == user?.name).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Parcels'),
        actions: [
          IconButton(
            icon: _checkingStatus
                ? const CircularProgressIndicator(strokeWidth: 2)
                : Icon(
                    _lockerOnline ? Icons.wifi : Icons.wifi_off,
                    color: _lockerOnline ? Colors.green : Colors.red,
                  ),
            onPressed: _checkLockerStatus,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              MockDatabase.currentUser = null;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Status indicator
          Container(
            padding: const EdgeInsets.all(12),
            color: _lockerOnline ? Colors.green[50] : Colors.red[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _checkingStatus
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _lockerOnline ? Icons.check_circle : Icons.error,
                        color: _lockerOnline ? Colors.green : Colors.red,
                        size: 16,
                      ),
                const SizedBox(width: 8),
                Text(
                  _lockerOnline
                      ? 'Locker System: ONLINE'
                      : 'Locker System: OFFLINE',
                  style: TextStyle(
                    color: _lockerOnline ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                if (!_lockerOnline && !_checkingStatus)
                  GestureDetector(
                    onTap: _checkLockerStatus,
                    child: const Text(
                      '(Tap to retry)',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Parcels list
          Expanded(
            child: studentParcels.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No parcels available',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: studentParcels.length,
                    itemBuilder: (context, index) {
                      final parcel = studentParcels[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.local_shipping,
                                      color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Locker: ${parcel.lockerNumber}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Status: ${parcel.status.toUpperCase()}',
                                style: const TextStyle(color: Colors.green),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'OTP: ${parcel.otp}',
                                style: const TextStyle(
                                  fontFamily: 'Monospace',
                                  fontSize: 16,
                                ),
                              ),
                              if (parcel.status == 'delivered') ...[
                                const SizedBox(height: 16),
                                _isSendingOTP
                                    ? const Center(
                                        child: CircularProgressIndicator())
                                    : ElevatedButton.icon(
                                        onPressed: _lockerOnline
                                            ? () => _sendOTPToHardware(
                                                  parcel.otp,
                                                  parcel.lockerNumber,
                                                  parcel.id,
                                                )
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _lockerOnline
                                              ? Colors.green
                                              : Colors.grey,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 16,
                                          ),
                                        ),
                                        icon: const Icon(Icons.send),
                                        label: const Text('Send OTP to Locker'),
                                      ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class CourierHomeScreen extends StatefulWidget {
  const CourierHomeScreen({super.key});

  @override
  State<CourierHomeScreen> createState() => _CourierHomeScreenState();
}

class _CourierHomeScreenState extends State<CourierHomeScreen> {
  final _studentNameController = TextEditingController();
  final _lockerNumberController = TextEditingController();

  void _logout() {
    MockDatabase.currentUser = null;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _deliverParcel() {
    if (_studentNameController.text.isEmpty ||
        _lockerNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final newParcel = Parcel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      studentName: _studentNameController.text,
      lockerNumber: _lockerNumberController.text,
      status: 'delivered',
      otp: MockDatabase.generateOTP(),
    );

    setState(() {
      MockDatabase.parcels.add(newParcel);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Parcel delivered successfully! OTP: ${newParcel.otp}'),
        duration: const Duration(seconds: 5),
      ),
    );

    _studentNameController.clear();
    _lockerNumberController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final courierDeliveries = MockDatabase.parcels;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Courier Dashboard'),
          actions: [
            // ADD THIS LOGOUT BUTTON
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.add), text: 'Deliver'),
              Tab(icon: Icon(Icons.history), text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Deliver Tab
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _studentNameController,
                            decoration: const InputDecoration(
                              labelText: 'Student Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _lockerNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Locker Number',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton.icon(
                            onPressed: _deliverParcel,
                            icon: const Icon(Icons.local_shipping),
                            label: const Text(
                              'Deliver Parcel',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 15,
                                horizontal: 30,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // History Tab
            courierDeliveries.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No delivery history',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: courierDeliveries.length,
                    itemBuilder: (context, index) {
                      final parcel = courierDeliveries[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading:
                              const Icon(Icons.inventory, color: Colors.blue),
                          title: Text('Student: ${parcel.studentName}'),
                          subtitle: Text(
                              'Locker: ${parcel.lockerNumber} • OTP: ${parcel.otp}'),
                          trailing: Chip(
                            label: Text(parcel.status),
                            backgroundColor: Colors.green[100],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

class BarcodeScannerScreen extends StatefulWidget {
  final String parcelId;
  final String lockerNumber;

  const BarcodeScannerScreen({
    super.key,
    required this.parcelId,
    required this.lockerNumber,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanning = true;
  bool _hasScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isScanning
                ? MobileScanner(
                    controller: cameraController,
                    onDetect: (capture) {
                      if (_hasScanned) return;

                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        if (barcode.rawValue != null) {
                          _handleBarcodeScan(barcode.rawValue!);
                        }
                      }
                    },
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 64),
                        SizedBox(height: 16),
                        Text(
                          'Parcel Collected Successfully!',
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black.withOpacity(0.8),
            child: const Text(
              'Scan the barcode on your parcel to confirm collection',
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _handleBarcodeScan(String barcodeData) {
    setState(() {
      _hasScanned = true;
      _isScanning = false;
    });

    // Stop the camera
    cameraController.stop();

    // Simulate barcode verification
    _verifyBarcode(barcodeData);
  }

  void _verifyBarcode(String barcodeData) {
    // In a real app, you would verify with your backend
    // For now, we'll assume any scan is successful

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Parcel Collected!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Parcel ID: ${widget.parcelId}'),
            Text('Locker: ${widget.lockerNumber}'),
            const SizedBox(height: 16),
            const Text('Collection confirmed successfully.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to home screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    // Update parcel status in mock database
    final parcelIndex = MockDatabase.parcels.indexWhere(
      (p) => p.id == widget.parcelId,
    );

    if (parcelIndex != -1) {
      // In a real app, you'd update the status to 'collected'
      setState(() {
        // MockDatabase.parcels[parcelIndex] = parcel with updated status
      });
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}
