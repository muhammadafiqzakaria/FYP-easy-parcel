import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';

class CourierBarcodeScannerScreen extends StatefulWidget {
  @override
  _CourierBarcodeScannerScreenState createState() =>
      _CourierBarcodeScannerScreenState();
}

class _CourierBarcodeScannerScreenState
    extends State<CourierBarcodeScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _hasScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan Student QR Code'),
        actions: [
          IconButton(
            color: Colors.white, // Assuming you want white icons
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: cameraController,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off);
                  case TorchState.on:
                    return const Icon(Icons.flash_on);
                  case TorchState.auto:
                    return const Icon(Icons.flash_auto);
                  case TorchState.unavailable:
                    return const Icon(Icons.no_flash);
                }
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
          // ✅ Correct Camera Switch Button
          IconButton(
            color: Colors.white, // Assuming you want white icons
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: cameraController,
              builder: (context, state, child) {
                // Access the 'cameraDirection' state
                switch (state.cameraDirection) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front);
                  case CameraFacing.back:
                    return const Icon(Icons.camera_rear);
                  case CameraFacing.unknown:
                  default:
                    return const Icon(Icons.camera);
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
            child: MobileScanner(
              controller: cameraController,
              onDetect: (capture) {
                if (_hasScanned) return;

                final barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    _handleBarcodeScan(barcode.rawValue!);
                    break;
                  }
                }
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.black87,
            child: Text(
              'Scan student QR code to automatically fill details',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _handleBarcodeScan(String scannedData) {
    setState(() {
      _hasScanned = true;
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
        title: Text('Invalid QR Code'),
        content: Text('Could not read student information from the QR code.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetScanner();
            },
            child: Text('Try Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('Manual Entry'),
          ),
        ],
      ),
    );
  }

  void _resetScanner() {
    setState(() {
      _hasScanned = false;
    });
    cameraController.start();
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}
