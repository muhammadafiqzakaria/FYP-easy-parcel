// lib/models/parcel_model.dart

class ParcelModel {
  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String courierId;
  final String courierName;
  final String lockerNumber;
  final String status;
  final DateTime deliveryTime;
  final DateTime? collectionTime;
  final String otp;
  final String barcode;

  ParcelModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.courierId,
    required this.courierName,
    required this.lockerNumber,
    required this.status,
    required this.deliveryTime,
    this.collectionTime,
    required this.otp,
    required this.barcode,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'courierId': courierId,
      'courierName': courierName,
      'lockerNumber': lockerNumber,
      'status': status,
      // Send as milliseconds (bigint)
      'deliveryTime': deliveryTime.millisecondsSinceEpoch,
      'collectionTime': collectionTime?.millisecondsSinceEpoch,
      'otp': otp,
      'barcode': barcode,
    };
  }

  factory ParcelModel.fromMap(Map<String, dynamic> map) {
    // --- THIS IS THE BULLETPROOF FIX ---
    // Helper function to safely parse a value that should be an int (milliseconds)
    int _parseMilliseconds(dynamic value) {
      if (value == null) {
        return 0; // Default to epoch time if null
      }
      if (value is int) {
        return value;
      }
      if (value is double) {
        return value.toInt();
      }
      if (value is String) {
        // Try to parse it as a number string (e.g., "123456")
        return num.tryParse(value)?.toInt() ?? 0;
      }
      return 0; // Default fallback
    }

    // Helper for nullable
    int? _parseNullableMilliseconds(dynamic value) {
      if (value == null) {
        return null;
      }
      if (value is int) {
        return value;
      }
      if (value is double) {
        return value.toInt();
      }
      if (value is String) {
        return num.tryParse(value)?.toInt();
      }
      return null;
    }
    // --- END OF FIX ---

    return ParcelModel(
      id: map['id'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      studentEmail: map['studentEmail'] ?? '',
      courierId: map['courierId'] ?? '',
      courierName: map['courierName'] ?? '',
      lockerNumber: map['lockerNumber'] ?? '',
      status: map['status'] ?? '',

      // Use the helper functions for safety
      deliveryTime: DateTime.fromMillisecondsSinceEpoch(
          _parseMilliseconds(map['deliveryTime'])),

      collectionTime: _parseNullableMilliseconds(map['collectionTime']) != null
          ? DateTime.fromMillisecondsSinceEpoch(
              _parseNullableMilliseconds(map['collectionTime'])!)
          : null,

      otp: map['otp'] ?? '',
      barcode: map['barcode'] ?? '',
    );
  }
}
