import 'package:flutter/material.dart';
import 'barcode_scanner_screen.dart';
import '../services/esp32_service.dart';
import 'login_screen.dart';
import '../models/user_model.dart';
import '../models/parcel_model.dart';
import '../services/supabase_service.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

// --- NEW ---
// Add "with SingleTickerProviderStateMixin" to handle tab animations
class _StudentHomeScreenState extends State<StudentHomeScreen>
    with SingleTickerProviderStateMixin {
  
  // --- NEW ---
  // Controller to manage the tabs
  late TabController _tabController;

  bool _isSendingOTP = false;
  bool _lockerOnline = false;
  bool _checkingStatus = false;
  List<ParcelModel> _studentParcels = [];

  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();

    // --- NEW ---
    // Initialize the TabController with 2 tabs
    _tabController = TabController(length: 2, vsync: this);

    _initializeConnection();
    _loadStudentParcels();
  }

  // --- NEW ---
  // Don't forget to dispose the controller!
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initializeConnection() {
    print('🚀 Initializing locker connection...');
    // ESP32Service.testConnection(); // This line was causing a hang
    _checkLockerStatus();
    _startPeriodicStatusCheck();
  }

  void _loadStudentParcels() {
    final currentUser = _supabaseService.currentUser;
    if (currentUser != null) {
      _supabaseService
          .getParcelsForStudent(currentUser.email)
          .listen((parcels) {
        if (mounted) {
          setState(() {
            _studentParcels = parcels;
          });
        }
      }, onError: (error) { // This error handler is important
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
    } else {
      setState(() {
        _studentParcels = [];
      });
    }
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
      barrierDismissible: false, // User must scan
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
              'After collecting, scan the barcode to confirm',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          // --- CHANGED ---
          // Make "Scan Barcode" the main action to confirm collection
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close the dialog
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
      _loadStudentParcels(); // Refresh the list after returning
    });
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

  void _refreshParcels() {
    _loadStudentParcels();
    _checkLockerStatus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Refreshed parcel list')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabaseService.currentUser;

    // --- NEW ---
    // Filter your parcels into two separate lists
    final List<ParcelModel> deliveredParcels = _studentParcels
        .where((p) => p.status == 'delivered')
        .toList();
    final List<ParcelModel> collectedParcels = _studentParcels
        .where((p) => p.status == 'collected')
        .toList();
    // --- END NEW ---

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Parcels'),
        actions: [
          _buildConnectionStatusIndicator(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshParcels,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
        // --- NEW ---
        // Add the TabBar to the bottom of the AppBar
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              text: 'Ready for Pickup',
              icon: Icon(Icons.inventory_2_outlined),
            ),
            Tab(
              text: 'History',
              icon: Icon(Icons.history),
            ),
          ],
        ),
        // --- END NEW ---
      ),
      body: Column(
        children: [
          _buildStatusBanner(),
          // --- CHANGED ---
          // Welcome header is now smaller and doesn't show parcel count
          _buildWelcomeHeader(user),
          // --- END CHANGED ---

          // --- NEW ---
          // Replace the old Expanded with a TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Ready for Pickup
                deliveredParcels.isEmpty
                    ? _buildEmptyState() // Use original empty state
                    : _buildParcelsList(
                        deliveredParcels), // Pass the filtered list

                // Tab 2: History
                collectedParcels.isEmpty
                    ? _buildHistoryEmptyState() // Use new history empty state
                    : _buildParcelsList(
                        collectedParcels), // Pass the filtered list
              ],
            ),
          ),
          // --- END NEW ---
        ],
      ),
    );
  }

  Widget _buildConnectionStatusIndicator() {
    return IconButton(
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
    );
  }

  Widget _buildStatusBanner() {
    return Container(
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
            _lockerOnline ? 'Locker System: ONLINE' : 'Locker System: OFFLINE',
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
    );
  }

  // --- CHANGED ---
  // Simplified the welcome header
  Widget _buildWelcomeHeader(User? user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Text(
        'Welcome, ${user?.name ?? 'Student'}!',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  // --- END CHANGED ---

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No parcels available',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            _lockerOnline
                ? 'Check back later for new deliveries'
                : 'Locker system is currently offline',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- NEW ---
  // A new empty state just for the history tab
  Widget _buildHistoryEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No collected parcels yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Your collected parcels will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  // --- END NEW ---

  // --- CHANGED ---
  // This widget now takes a list as a parameter
  Widget _buildParcelsList(List<ParcelModel> parcels) {
    return ListView.builder(
      itemCount: parcels.length,
      itemBuilder: (context, index) {
        final parcel = parcels[index];
        return _buildParcelCard(parcel);
      },
    );
  }
  // --- END CHANGED ---

  Widget _buildParcelCard(ParcelModel parcel) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_shipping, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Locker: ${parcel.lockerNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                _buildStatusBadge(parcel.status),
              ],
            ),
            const SizedBox(height: 12),
            _buildParcelDetails(parcel),
            // Only show the button if the status is 'delivered'
            if (parcel.status == 'delivered') ...[
              const SizedBox(height: 16),
              _buildActionButton(parcel),
            ],
            // --- NEW ---
            // Here you could add your "Retrieve OTP" button for 'collected' parcels
            if (parcel.status == 'collected') ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retrieve OTP'),
                onPressed: () {
                  // TODO: Add logic for retrieving OTP
                  // This will require database changes (a counter)
                  // and a new Edge Function.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Retrieve OTP feature not yet implemented')),
                  );
                },
              )
            ]
            // --- END NEW ---
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = status == 'delivered' ? Colors.orange : Colors.green;
    final text = status == 'delivered' ? 'READY FOR PICKUP' : 'COLLECTED';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
        const SizedBox(height: 4),
        Text(
          'OTP: ${parcel.otp}',
          style: const TextStyle(
            fontFamily: 'Monospace',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (parcel.status == 'collected') ...[
          const SizedBox(height: 4),
          const Text(
            'Parcel collected successfully',
            style: TextStyle(
              color: Colors.green,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton(ParcelModel parcel) {
    return _isSendingOTP
        ? const Center(child: CircularProgressIndicator())
        : ElevatedButton.icon(
            onPressed: _lockerOnline
                ? () => _sendOTPToHardware(
                      parcel.otp,
                      parcel.lockerNumber,
                      parcel.id,
                    )
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _lockerOnline ? Colors.green : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              minimumSize: const Size(double.infinity, 50),
            ),
            icon: const Icon(Icons.send),
            label: const Text(
              'Get OTP',
              style: TextStyle(fontSize: 16),
            ),
          );
  }
}