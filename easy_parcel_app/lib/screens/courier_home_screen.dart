import 'package:flutter/material.dart';
import 'courier_barcode_scanner_screen.dart';
import '../models/parcel_model.dart';
import '../services/parcel_service.dart';
import '../utils/mock_database.dart';

class CourierHomeScreen extends StatefulWidget {
  const CourierHomeScreen({super.key});

  @override
  State<CourierHomeScreen> createState() => _CourierHomeScreenState();
}

class _CourierHomeScreenState extends State<CourierHomeScreen> {
  final _studentIdController = TextEditingController();
  final _studentNameController = TextEditingController();
  final _studentEmailController = TextEditingController();
  final _lockerNumberController = TextEditingController();

  bool _isLoading = false;
  bool _showManualForm = false;

  @override
  void dispose() {
    _studentIdController.dispose();
    _studentNameController.dispose();
    _studentEmailController.dispose();
    _lockerNumberController.dispose();
    super.dispose();
  }

  void _startBarcodeScan(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CourierBarcodeScannerScreen(),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      // Populate fields with scanned data
      setState(() {
        _studentIdController.text = result['studentId'] ?? '';
        _studentNameController.text = result['studentName'] ?? '';
        _studentEmailController.text = result['studentEmail'] ?? '';
        _showManualForm = true;
      });
    }
  }

  void _toggleManualForm() {
    setState(() {
      _showManualForm = !_showManualForm;
      if (!_showManualForm) {
        _clearForm();
      }
    });
  }

  void _clearForm() {
    _studentIdController.clear();
    _studentNameController.clear();
    _studentEmailController.clear();
    _lockerNumberController.clear();
  }

  void _deliverParcel() {
    if (_lockerNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter locker number')),
      );
      return;
    }

    if (_studentIdController.text.isEmpty &&
        _studentEmailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please provide student ID or email')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // For now, using mock data - replace with actual ParcelService call
    final newParcel = ParcelModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      studentId: _studentIdController.text,
      studentName: _studentNameController.text.isNotEmpty
          ? _studentNameController.text
          : 'Student ${_studentIdController.text}',
      studentEmail: _studentEmailController.text,
      courierId: 'courier_123', // Mock courier ID
      courierName: 'Courier Staff',
      lockerNumber: _lockerNumberController.text,
      status: 'delivered',
      deliveryTime: DateTime.now(),
      otp: MockDatabase.generateOTP(),
      barcode: 'BC${DateTime.now().millisecondsSinceEpoch}',
    );

    Future.delayed(Duration(seconds: 1), () {
      setState(() {
        _isLoading = false;
      });

      _showSuccessDialog(newParcel);
      _clearForm();
    });
  }

  void _showSuccessDialog(ParcelModel parcel) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Parcel Delivered!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping, size: 48, color: Colors.green),
            SizedBox(height: 16),
            Text('Parcel delivered successfully!', textAlign: TextAlign.center),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'Student OTP:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    parcel.otp,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Locker: ${parcel.lockerNumber}',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Student can collect the parcel using this OTP',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _logout() {
    MockDatabase.currentUser = null;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Courier Dashboard'),
          actions: [
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: _logout,
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(icon: Icon(Icons.add), text: 'Deliver'),
              Tab(icon: Icon(Icons.history), text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Deliver Tab with Barcode Scanner
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Scan Barcode Section
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(Icons.qr_code_scanner,
                              size: 64, color: Colors.blue),
                          SizedBox(height: 16),
                          Text(
                            'Scan Student Barcode',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Scan the student\'s QR code to automatically fill their details',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                          SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => _startBarcodeScan(context),
                            icon: Icon(Icons.qr_code_scanner),
                            label: Text('Scan Barcode'),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                  vertical: 15, horizontal: 30),
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text('OR'),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _toggleManualForm,
                            icon: Icon(Icons.keyboard),
                            label: Text(_showManualForm
                                ? 'Hide Manual Entry'
                                : 'Enter Details Manually'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Manual Form Section
                  if (_showManualForm) ...[
                    SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              'Manual Student Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _studentIdController,
                              decoration: InputDecoration(
                                labelText: 'Student ID',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.badge),
                              ),
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _studentNameController,
                              decoration: InputDecoration(
                                labelText: 'Student Name',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                              ),
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _studentEmailController,
                              decoration: InputDecoration(
                                labelText: 'Student Email',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.email),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Locker Number Section
                  SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _lockerNumberController,
                            decoration: InputDecoration(
                              labelText: 'Locker Number',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock),
                              hintText: 'e.g., A101, B202',
                            ),
                          ),
                          SizedBox(height: 20),
                          _isLoading
                              ? Center(child: CircularProgressIndicator())
                              : ElevatedButton.icon(
                                  onPressed: _deliverParcel,
                                  icon: Icon(Icons.local_shipping),
                                  label: Text('Deliver Parcel'),
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(vertical: 15),
                                    minimumSize: Size(double.infinity, 50),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // History Tab (empty for now)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No delivery history'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
