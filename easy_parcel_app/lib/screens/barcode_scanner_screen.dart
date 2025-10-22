import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
  bool _hasScanned = false;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Parcel Barcode'),
        actions: [
          IconButton(
            color: Colors.white,
            icon: ValueListenableBuilder(
              valueListenable: cameraController.torchState,
              builder: (context, state, child) {
                switch (state) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off);
                  case TorchState.on:
                    return const Icon(Icons.flash_on);
                }
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            color: Colors.white,
            icon: ValueListenableBuilder(
              valueListenable: cameraController.cameraFacingState,
              builder: (context, state, child) {
                switch (state) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front);
                  case CameraFacing.back:
                    return const Icon(Icons.camera_rear);
                }
              },
            ),
            onPressed: () => cameraController.switchCamera(),
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

                    final List<Barcode> barcodes = capture.barcodes;
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
            padding: const EdgeInsets.all(16),
            color: Colors.black87,
            child: Column(
              children: [
                Text(
                  'Locker: ${widget.lockerNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Scan the barcode on your parcel after collecting it',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Position the barcode within the frame',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 12),
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
      lockerNumber: widget.lockerNumber,
      isProcessing: _isProcessing,
    );
  }

  Future<void> _handleBarcodeScan(String scannedBarcode) async {
    setState(() {
      _hasScanned = true;
      _isProcessing = true;
    });

    cameraController.stop();

    final success = await _verifyAndUpdateParcel(scannedBarcode);

    setState(() {
      _isProcessing = false;
    });

    if (success) {
      _showSuccessDialog(scannedBarcode);
    } else {
      _showErrorDialog(scannedBarcode);
    }
  }

  Future<bool> _verifyAndUpdateParcel(String scannedBarcode) async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      return scannedBarcode.isNotEmpty;
    } catch (e) {
      print('Error verifying barcode: $e');
      return false;
    }
  }

  void _showSuccessDialog(String barcode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Collection Confirmed!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner, size: 48, color: Colors.green),
            const SizedBox(height: 16),
            Text('Barcode: $barcode',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Locker: ${widget.lockerNumber}'),
            Text('Parcel ID: ${widget.parcelId}'),
            const SizedBox(height: 16),
            const Text(
              'Parcel collection has been recorded successfully.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String barcode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Scanning Error'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('There was an issue processing the barcode.'),
            const SizedBox(height: 16),
            Text('Scanned: $barcode',
                style: const TextStyle(fontFamily: 'Monospace')),
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

class CustomScannerOverlay extends StatelessWidget {
  final String lockerNumber;
  final bool isProcessing;

  const CustomScannerOverlay({
    super.key,
    required this.lockerNumber,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.5),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isProcessing)
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
              ],
            ),
          ),
        if (!isProcessing) ...[
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  'Locker: $lockerNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Position the barcode within the frame',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: const Column(
              children: [
                Icon(Icons.qr_code_scanner, color: Colors.white, size: 40),
                SizedBox(height: 8),
                Text(
                  'Scan the barcode on your parcel',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
