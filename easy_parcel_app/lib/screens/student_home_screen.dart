import 'package:flutter/material.dart';
import 'barcode_scanner_screen.dart';
import '../services/esp32_service.dart';
import 'login_screen.dart';
import '../models/parcel_model.dart';
import '../services/supabase_service.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen>
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;

  bool _isSendingOTP = false;
  bool _lockerOnline = false;
  bool _checkingStatus = false;
  List<ParcelModel> _studentParcels = [];

  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _initializeConnection();
    _loadStudentParcels();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initializeConnection() {
    print('🚀 Initializing locker connection...');
    _checkLockerStatus();
    _startPeriodicStatusCheck();
  }

  void _loadStudentParcels() {
    final currentUser = _supabaseService.currentUser;
    if (currentUser?.email == null) {
      setState(() {
        _studentParcels = [];
      });
      return;
    }
    
    _supabaseService
        .getParcelsForStudent(currentUser!.email)
        .listen((parcels) {
      if (mounted) {
        setState(() {
          _studentParcels = parcels;
        });
      }
    }, onError: (error) {
      if (mounted) {
        print('❌❌❌ Error loading parcels: $error ❌❌❌');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading parcels: $error'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _studentParcels = [];
        });
      }
    });
  }

  void _logout() {
    _supabaseService.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
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

    if (mounted) {
      setState(() {
        _lockerOnline = online;
        _checkingStatus = false;
      });
    }
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
      _showSuccessDialog(otp, lockerNumber, parcelId);
    } else {
      _showErrorDialog();
    }
  }

  void _showSuccessDialog(String otp, String lockerNumber, String parcelId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                borderRadius: BorderRadius.circular(12),
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
              'After collecting, scan the barcode to confirm',
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              Navigator.pop(context);
              _navigateToBarcodeScanner(parcelId, lockerNumber);
            },
            child: const Text('Scan Barcode to Confirm'),
          ),
        ],
      ),
    );
  }

  void _navigateToBarcodeScanner(String parcelId, String lockerNumber) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerScreen(
          parcelId: parcelId,
          lockerNumber: lockerNumber,
        ),
      ),
    ).then((_) {
      _loadStudentParcels();
    });
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
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
            child: Text(
              'OK',
              style: TextStyle(color: Colors.blue[600]),
            ),
          ),
        ],
      ),
    );
  }

  void _refreshParcels() {
    _loadStudentParcels();
    _checkLockerStatus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshed parcel list'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabaseService.currentUser;

    final List<ParcelModel> deliveredParcels = _studentParcels
        .where((p) => p.status == 'delivered')
        .toList();
    final List<ParcelModel> collectedParcels = _studentParcels
        .where((p) => p.status == 'collected')
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            // Logo - Replace with your actual logo
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
              'Easy Parcel',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          _buildConnectionStatusIndicator(),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.grey[700]),
            onPressed: _refreshParcels,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.grey[700]),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Welcome Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${user?.name ?? 'Student'}!',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage your parcel deliveries',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Tab Bar
              Container(
                color: Colors.grey[50],
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.blue[600],
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: Colors.blue[600],
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(
                      text: 'Ready for Pickup',
                    ),
                    Tab(
                      text: 'History',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Ready for Pickup
          deliveredParcels.isEmpty
              ? _buildEmptyState()
              : _buildParcelsList(deliveredParcels),
          
          // Tab 2: History
          collectedParcels.isEmpty
              ? _buildHistoryEmptyState()
              : _buildParcelsList(collectedParcels),
        ],
      ),
    );
  }

  Widget _buildConnectionStatusIndicator() {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: IconButton(
        icon: _checkingStatus
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                _lockerOnline ? Icons.wifi : Icons.wifi_off,
                color: _lockerOnline ? Colors.green : Colors.red,
              ),
        onPressed: _checkLockerStatus,
        tooltip: _lockerOnline ? 'Locker Online' : 'Locker Offline',
      ),
    );
  }

  Widget _buildEmptyState() {
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
              Icons.inventory_2_outlined,
              size: 50,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No parcels available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _lockerOnline
                ? 'Check back later for new deliveries'
                : 'Locker system is currently offline',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryEmptyState() {
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
              Icons.history_toggle_off,
              size: 50,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No collected parcels yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your collected parcels will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildParcelsList(List<ParcelModel> parcels) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: parcels.length,
      itemBuilder: (context, index) {
        final parcel = parcels[index];
        return _buildParcelCard(parcel);
      },
    );
  }

  Widget _buildParcelCard(ParcelModel parcel) {
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: parcel.status == 'delivered' 
                        ? Colors.orange[50] 
                        : Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.local_shipping,
                    color: parcel.status == 'delivered' 
                        ? Colors.orange 
                        : Colors.green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Locker ${parcel.lockerNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                _buildStatusBadge(parcel.status),
              ],
            ),
            const SizedBox(height: 16),
            _buildParcelDetails(parcel),
            if (parcel.status == 'delivered') ...[
              const SizedBox(height: 16),
              _buildActionButton(parcel),
            ],
            if (parcel.status == 'collected') ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue[600],
                  side: BorderSide(color: Colors.blue[600]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retrieve OTP'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Retrieve OTP feature not yet implemented'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                  );
                },
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = status == 'delivered' ? Colors.orange : Colors.green;
    final text = status == 'delivered' ? 'READY FOR PICKUP' : 'COLLECTED';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildParcelDetails(ParcelModel parcel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status: ${parcel.status.toUpperCase()}',
          style: TextStyle(
            color: parcel.status == 'delivered' ? Colors.orange : Colors.green,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'OTP: ',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                parcel.otp,
                style: const TextStyle(
                  fontFamily: 'Monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        if (parcel.status == 'collected') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[400], size: 16),
              const SizedBox(width: 4),
              const Text(
                'Parcel collected successfully',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton(ParcelModel parcel) {
    return _isSendingOTP
        ? const Center(child: CircularProgressIndicator())
        : ElevatedButton(
            onPressed: _lockerOnline
                ? () => _sendOTPToHardware(
                      parcel.otp,
                      parcel.lockerNumber,
                      parcel.id,
                    )
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _lockerOnline ? Colors.blue[600] : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text(
              'Get OTP',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          );
  }
}