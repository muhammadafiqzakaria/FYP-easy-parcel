class ParcelModel {
  final String id;
  final String studentId;
  final String studentName;
  final String courierId;
  final String courierName;
  final String lockerNumber;
  final String status; // 'pending', 'delivered', 'collected'
  final DateTime deliveryTime;
  final DateTime? collectionTime;
  final String otp;
  final String barcode; // Add this field

  ParcelModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.courierId,
    required this.courierName,
    required this.lockerNumber,
    required this.status,
    required this.deliveryTime,
    this.collectionTime,
    required this.otp,
    required this.barcode, // Add this
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'courierId': courierId,
      'courierName': courierName,
      'lockerNumber': lockerNumber,
      'status': status,
      'deliveryTime': deliveryTime.millisecondsSinceEpoch,
      'collectionTime': collectionTime?.millisecondsSinceEpoch,
      'otp': otp,
      'barcode': barcode, // Add this
    };
  }

  factory ParcelModel.fromMap(Map<String, dynamic> map) {
    return ParcelModel(
      id: map['id'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      courierId: map['courierId'] ?? '',
      courierName: map['courierName'] ?? '',
      lockerNumber: map['lockerNumber'] ?? '',
      status: map['status'] ?? '',
      deliveryTime: DateTime.fromMillisecondsSinceEpoch(map['deliveryTime']),
      collectionTime: map['collectionTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['collectionTime'])
          : null,
      otp: map['otp'] ?? '',
      barcode: map['barcode'] ?? '', // Add this
    );
  }

  ParcelModel copyWith({
    String? status,
    DateTime? collectionTime,
  }) {
    return ParcelModel(
      id: id,
      studentId: studentId,
      studentName: studentName,
      courierId: courierId,
      courierName: courierName,
      lockerNumber: lockerNumber,
      status: status ?? this.status,
      deliveryTime: deliveryTime,
      collectionTime: collectionTime ?? this.collectionTime,
      otp: otp,
      barcode: barcode,
    );
  }
}
