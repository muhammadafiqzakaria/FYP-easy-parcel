import 'package:flutter/material.dart';
import 'courier_barcode_scanner_screen.dart';
import '../models/parcel_model.dart';
import '../services/supabase_service.dart';
import 'login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

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

  final SupabaseService _supabaseService = SupabaseService();

  List<ParcelModel> _deliveryHistory = [];

  @override
  void initState() {
    super.initState();
    _loadDeliveryHistory();
  }

  void _loadDeliveryHistory() {
    final currentUser = _supabaseService.currentUser;
    if (currentUser?.id == null) {
      setState(() {
        _deliveryHistory = [];
      });
      return;
    }
    
    _supabaseService.getParcelsForCourier(currentUser!.id).listen(
      (parcels) {
        if (mounted) {
          setState(() {
            _deliveryHistory = parcels;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          debugPrint('❌❌❌ Error loading courier history: $error ❌❌❌');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading history: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() {
            _deliveryHistory = []; 
          });
        }
      },
    );
  }

  void _startBarcodeScan(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CourierBarcodeScannerScreen(),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
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

  void _deliverParcel() async {
    if (_lockerNumberController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter locker number')),
        );
      }
      return;
    }

    if (_studentIdController.text.isEmpty &&
        _studentEmailController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please provide student ID or email')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final currentUser = _supabaseService.currentUser;

    final newParcel = await _supabaseService.createParcel(
      studentId: _studentIdController.text,
      studentName: _studentNameController.text.isNotEmpty
          ? _studentNameController.text
          : 'Student ${_studentIdController.text}',
      studentEmail: _studentEmailController.text,
      courierId: currentUser?.id ?? 'courier_123',
      courierName: currentUser?.name ?? 'Courier Staff',
      lockerNumber: _lockerNumberController.text,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    if (newParcel != null) {
      await _sendDeliveryNotification(newParcel);
      if (mounted) {
        _showSuccessDialog(newParcel);
      }
      _clearForm();
      _loadDeliveryHistory();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create parcel')),
        );
      }
    }
  }

  void _showSuccessDialog(ParcelModel parcel) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Parcel Delivered!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_shipping, size: 48, color: Colors.green),
            const SizedBox(height: 16),
            const Text('Parcel delivered successfully!',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text(
                    'Student OTP:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    parcel.otp,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Locker: ${parcel.lockerNumber}',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Student can collect the parcel using this OTP',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _logout() {
    _supabaseService.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Widget _buildDeliveryHistory() {
    if (_deliveryHistory.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.history,
                size: 50,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No delivery history',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your delivery history will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _deliveryHistory.length,
      itemBuilder: (context, index) {
        final parcel = _deliveryHistory[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: Colors.grey[100]!,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(20),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.local_shipping,
                color: Colors.blue[600],
                size: 20,
              ),
            ),
            title: Text(
              'Locker: ${parcel.lockerNumber}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text('Student: ${parcel.studentName}'),
                Text('Email: ${parcel.studentEmail}'),
                Text('Status: ${parcel.status.toUpperCase()}'),
                Text('Delivery: ${_formatDate(parcel.deliveryTime)}'),
                if (parcel.collectionTime != null)
                  Text('Collection: ${_formatDate(parcel.collectionTime!)}'),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: parcel.status == 'delivered'
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: parcel.status == 'delivered'
                      ? Colors.orange
                      : Colors.green,
                ),
              ),
              child: Text(
                parcel.status == 'delivered' ? 'PENDING' : 'COLLECTED',
                style: TextStyle(
                  color: parcel.status == 'delivered'
                      ? Colors.orange
                      : Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _studentNameController.dispose();
    _studentEmailController.dispose();
    _lockerNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_shipping,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Courier Dashboard',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: IconButton(
                icon: Icon(Icons.logout, color: Colors.grey[700]),
                onPressed: _logout,
              ),
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.blue[600],
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Colors.blue[600],
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
            tabs: const [
              Tab(icon: Icon(Icons.add), text: 'Deliver'),
              Tab(icon: Icon(Icons.history), text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Deliver Tab
            Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.grey[100]!,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.qr_code_scanner,
                                size: 30,
                                color: Colors.blue[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Scan Student Barcode',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Scan the student QR code to automatically fill their details',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => _startBarcodeScan(context),
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text('Scan Barcode'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 15, horizontal: 30),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Row(
                              children: [
                                Expanded(child: Divider()),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('OR'),
                                ),
                                Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _toggleManualForm,
                              icon: const Icon(Icons.keyboard),
                              label: Text(_showManualForm
                                  ? 'Hide Manual Entry'
                                  : 'Enter Details Manually'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue[600],
                                side: BorderSide(color: Colors.blue[600]!),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_showManualForm) ...[
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.grey[100]!,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Text(
                                'Parcel Delivery Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _studentIdController,
                                decoration: InputDecoration(
                                  labelText: 'Student ID',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  prefixIcon: const Icon(Icons.badge),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _studentNameController,
                                decoration: InputDecoration(
                                  labelText: 'Student Name',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  prefixIcon: const Icon(Icons.person),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _studentEmailController,
                                decoration: InputDecoration(
                                  labelText: 'Student Email',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  prefixIcon: const Icon(Icons.email),
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _lockerNumberController,
                                decoration: InputDecoration(
                                  labelText: 'Locker Number',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  prefixIcon: const Icon(Icons.lock),
                                  hintText: 'e.g., A101, B202',
                                ),
                              ),
                              const SizedBox(height: 20),
                              _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator())
                                  : ElevatedButton.icon(
                                      onPressed: _deliverParcel,
                                      icon: const Icon(Icons.local_shipping),
                                      label: const Text('Deliver Parcel'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue[600],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 15),
                                        minimumSize:
                                            const Size(double.infinity, 50),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // History Tab
            _buildDeliveryHistory(),
          ],
        ),
      ),
    );
  }
}

Future<void> _sendDeliveryNotification(ParcelModel parcel) async {
  try {
    debugPrint('📧 Attempting to send notification for parcel: ${parcel.id}');
    
    // First, get the student's user_id from their email
    final studentProfileResponse = await Supabase.instance.client
        .from('profiles')
        .select('id')
        .eq('email', parcel.studentEmail)
        .maybeSingle();

    if (studentProfileResponse != null && studentProfileResponse['id'] != null) {
      final studentId = studentProfileResponse['id'] as String;
      
      // Store notification in database using user_id
      await Supabase.instance.client.from('notifications').insert({
        'user_id': studentId,
        'title': 'New Parcel Delivery',
        'body': 'You have a new parcel waiting at Locker ${parcel.lockerNumber}. OTP: ${parcel.otp}',
        'type': 'delivery',
        'parcel_id': parcel.id,
      });
      
      debugPrint('✅ Delivery notification stored for user: $studentId');
    } else {
      debugPrint('❌ Student profile not found for email: ${parcel.studentEmail}');
    }
    
  } catch (e) {
    debugPrint('❌ Error sending notification: $e');
  }
}