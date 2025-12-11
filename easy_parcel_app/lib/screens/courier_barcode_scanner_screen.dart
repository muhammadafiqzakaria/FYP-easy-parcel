import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';

class CourierBarcodeScannerScreen extends StatefulWidget {
  const CourierBarcodeScannerScreen({super.key});

  @override
  State<CourierBarcodeScannerScreen> createState() =>
      _CourierBarcodeScannerScreenState();
}

class _CourierBarcodeScannerScreenState
    extends State<CourierBarcodeScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _hasScanned = false;
  bool _isProcessing = false;
  bool _torchEnabled = false;
  CameraFacing _cameraFacing = CameraFacing.back;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Scan Student QR Code',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _torchEnabled ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _torchEnabled = !_torchEnabled;
              });
              cameraController.toggleTorch();
            },
          ),
          IconButton(
            icon: Icon(
              _cameraFacing == CameraFacing.back
                  ? Icons.camera_rear
                  : Icons.camera_front,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _cameraFacing = _cameraFacing == CameraFacing.back
                    ? CameraFacing.front
                    : CameraFacing.back;
              });
              cameraController.switchCamera();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: cameraController,
                  onDetect: (capture) {
                    if (_hasScanned || _isProcessing) return;

                    final barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null) {
                        _handleBarcodeScan(barcode.rawValue!);
                        break;
                      }
                    }
                  },
                ),
                _buildScannerOverlay(),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.black87,
            child: Column(
              children: [
                const Icon(
                  Icons.qr_code_scanner,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Scan Student QR Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Position the QR code within the frame to automatically fill student details',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                if (_isProcessing)
                  const Column(
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Processing QR Code...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return CustomScannerOverlay(
      isProcessing: _isProcessing,
    );
  }

  void _handleBarcodeScan(String scannedData) {
    setState(() {
      _hasScanned = true;
      _isProcessing = true;
    });

    cameraController.stop();

    final studentData = _processScannedData(scannedData);

    if (studentData != null) {
      Navigator.pop(context, studentData);
    } else {
      _showErrorDialog(scannedData);
    }
  }

  Map<String, dynamic>? _processScannedData(String data) {
    try {
      final jsonData = json.decode(data);
      if (jsonData is Map<String, dynamic>) {
        return {
          'studentId': jsonData['studentId'] ?? '',
          'studentName': jsonData['studentName'] ?? '',
          'studentEmail': jsonData['studentEmail'] ?? '',
        };
      }
    } catch (e) {
      final emailRegex =
          RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      if (emailRegex.hasMatch(data)) {
        return {
          'studentId': '',
          'studentName': '',
          'studentEmail': data,
        };
      }

      return {
        'studentId': data,
        'studentName': '',
        'studentEmail': '',
      };
    }
    return null;
  }

  void _showErrorDialog(String scannedData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Invalid QR Code'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not read student information from the QR code.'),
            SizedBox(height: 8),
            Text(
              'Please make sure you are scanning a valid student QR code.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetScanner();
            },
            child: const Text('Try Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Manual Entry'),
          ),
        ],
      ),
    );
  }

  void _resetScanner() {
    setState(() {
      _hasScanned = false;
      _isProcessing = false;
    });
    cameraController.start();
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}

class CustomScannerOverlay extends StatefulWidget {
  final bool isProcessing;

  const CustomScannerOverlay({
    super.key,
    required this.isProcessing,
  });

  @override
  State<CustomScannerOverlay> createState() => _CustomScannerOverlayState();
}

class _CustomScannerOverlayState extends State<CustomScannerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Simple border frame without overlay
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
            ),
          ),
        ),
        
        // Scanning line animation
        if (!widget.isProcessing)
          Center(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Positioned(
                  top: MediaQuery.of(context).size.height * 0.5 - 125 + (250 * _animation.value),
                  left: MediaQuery.of(context).size.width * 0.5 - 125,
                  child: Container(
                    width: 250,
                    height: 3,
                    color: Colors.green,
                  ),
                );
              },
            ),
          ),
        
        // Top instructions
        Positioned(
          top: 100,
          left: 0,
          right: 0,
          child: Column(
            children: [
              if (widget.isProcessing) ...const [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                SizedBox(height: 16),
                Text(
                  'Processing...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ] else ...const [
                Text(
                  'Scan Student QR Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Position within the frame',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class ScannerCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final path = Path();
    const cornerLength = 20.0;

    // Top-left corner
    path.moveTo(0, cornerLength);
    path.lineTo(0, 0);
    path.lineTo(cornerLength, 0);

    // Top-right corner
    path.moveTo(size.width - cornerLength, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, cornerLength);

    // Bottom-right corner
    path.moveTo(size.width, size.height - cornerLength);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width - cornerLength, size.height);

    // Bottom-left corner
    path.moveTo(cornerLength, size.height);
    path.lineTo(0, size.height);
    path.lineTo(0, size.height - cornerLength);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}